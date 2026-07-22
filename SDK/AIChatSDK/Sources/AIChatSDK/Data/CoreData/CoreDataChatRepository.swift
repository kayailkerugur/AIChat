//
//  CoreDataChatRepository.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//
//  Core Data implementation of both repository protocols — the
//  drop-in replacement for InMemoryChatRepository. All work runs on
//  background contexts via `context.perform`; results cross the
//  boundary as domain models, never as managed objects.
//
//  Save errors are logged AND rethrown (spec: "context save hataları
//  yutulmamalı; loglanmalı ve uygun durumda kullanıcıya gösterilmelidir").
//

import Foundation
import CoreData

public final class CoreDataChatRepository: ConversationRepository, MessageRepository, @unchecked Sendable {

    private let persistence: PersistenceController
    private let attachmentFileStore: AttachmentFileStore
    private let logger = SDKLogger.persistence

    public init(
        persistence: PersistenceController,
        attachmentFileStore: AttachmentFileStore
    ) {
        self.persistence = persistence
        self.attachmentFileStore = attachmentFileStore
    }

    // MARK: - ConversationRepository

    public func conversations() async throws -> [Conversation] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = CDConversation.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
            return try context.fetch(request).map { $0.toDomain() }
        }
    }

    public func searchConversations(matching query: String) async throws -> [Conversation] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try await conversations() }

        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = CDConversation.fetchRequest()
            request.predicate = NSPredicate(
                format: "title CONTAINS[cd] %@ OR ANY messages.content CONTAINS[cd] %@",
                trimmed, trimmed
            )
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
            return try context.fetch(request).map { $0.toDomain() }
        }
    }

    public func create(_ conversation: Conversation) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let entity = CDConversation(context: context)
            entity.apply(conversation)
            try self.save(context, action: "create conversation")
        }
    }

    public func rename(conversationID: UUID, to title: String) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            guard let entity = try self.fetchConversation(conversationID, in: context)
            else { return }
            entity.title = title
            try self.save(context, action: "rename conversation")
        }
    }

    public func touch(conversationID: UUID, at date: Date) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            guard let entity = try self.fetchConversation(conversationID, in: context)
            else { return }
            entity.updatedAt = date
            try self.save(context, action: "touch conversation")
        }
    }

    public func delete(conversationID: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            guard let entity = try self.fetchConversation(conversationID, in: context)
            else { return }
            self.deleteAttachmentFiles(in: entity)
            // Messages go with it — Cascade delete rule on the
            // `messages` relationship (spec acceptance criterion 10).
            context.delete(entity)
            try self.save(context, action: "delete conversation")
        }
    }

    // MARK: - MessageRepository

    public func messages(inConversation conversationID: UUID) async throws -> [ChatMessage] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = CDMessage.fetchRequest()
            request.predicate = NSPredicate(
                format: "conversation.id == %@", conversationID as CVarArg
            )
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: true)
            ]
            return try context.fetch(request).map {
                $0.toDomain(attachmentFileStore: self.attachmentFileStore)
            }
        }
    }

    public func append(_ message: ChatMessage, toConversation conversationID: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            guard let conversation = try self.fetchConversation(conversationID, in: context)
            else {
                self.logger.error("append: conversation not found")
                return
            }
            let entity = CDMessage(context: context)
            entity.apply(message)
            entity.conversation = conversation
            try self.replaceAttachments(for: entity, with: message.attachments, in: context)
            try self.save(context, action: "append message")
        }
    }

    public func update(_ message: ChatMessage, inConversation conversationID: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            guard let entity = try self.fetchMessage(message.id, in: context)
            else { return }
            entity.apply(message)
            try self.replaceAttachments(for: entity, with: message.attachments, in: context)
            try self.save(context, action: "update message")
        }
    }

    public func deleteMessage(id: UUID, inConversation conversationID: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            guard let entity = try self.fetchMessage(id, in: context) else { return }
            self.deleteAttachmentFiles(in: entity)
            context.delete(entity)
            try self.save(context, action: "delete message")
        }
    }

    // MARK: - Launch repair

    /// Puts rows stuck in a non-terminal status (app crashed or was
    /// force-quit mid-stream) into a safe, explainable state.
    /// Called once at launch (spec §3.3: "bozuk veya yarım kalmış stream
    /// kayıtları uygulama yeniden açıldığında güvenli duruma alınmalıdır").
    public func repairInterruptedStreams() async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = CDMessage.fetchRequest()
            request.predicate = NSPredicate(
                format: "status IN %@",
                [MessageStatus.streaming.rawValue, MessageStatus.sending.rawValue]
            )
            let stuck = try context.fetch(request)
            guard !stuck.isEmpty else { return }

            for message in stuck {
                message.status = MessageStatus.failed.rawValue
                message.errorDescription =
                    "Uygulama kapandığı için yanıt tamamlanamadı."
            }
            try self.save(context, action: "repair interrupted streams")
            self.logger.notice(
                "Repaired \(stuck.count) interrupted stream message(s) at launch"
            )
        }
    }

    // MARK: - Helpers

    private func fetchConversation(
        _ id: UUID, in context: NSManagedObjectContext
    ) throws -> CDConversation? {
        let request = CDConversation.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchMessage(
        _ id: UUID, in context: NSManagedObjectContext
    ) throws -> CDMessage? {
        let request = CDMessage.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func save(_ context: NSManagedObjectContext, action: String) throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            // Log AND rethrow — callers decide how to surface it to the user.
            logger.error(
                "Core Data save failed (\(action)): \(error.localizedDescription)"
            )
            throw error
        }
    }

    private func replaceAttachments(
        for message: CDMessage,
        with attachments: [ChatAttachment],
        in context: NSManagedObjectContext
    ) throws {
        let newRows = try attachments.enumerated().map { index, attachment in
            let relativePath = try attachmentFileStore.write(
                data: attachment.data,
                fileName: attachment.fileName,
                attachmentID: attachment.id,
                messageID: message.id ?? UUID()
            )
            return (
                index: index,
                attachment: attachment,
                relativePath: relativePath
            )
        }
        let newRelativePaths = Set(newRows.map(\.relativePath))

        let existing = (message.attachments as? Set<CDAttachment>) ?? []
        for attachment in existing {
            if let relativePath = attachment.relativePath,
               !newRelativePaths.contains(relativePath) {
                attachmentFileStore.delete(relativePath: relativePath)
            }
            context.delete(attachment)
        }

        for (index, attachment, relativePath) in newRows {
            let entity = CDAttachment(context: context)
            entity.apply(
                attachment,
                sortIndex: Int32(index),
                relativePath: relativePath
            )
            entity.message = message
        }
    }

    private func deleteAttachmentFiles(in conversation: CDConversation) {
        let messages = (conversation.messages as? Set<CDMessage>) ?? []
        for message in messages {
            deleteAttachmentFiles(in: message)
        }
    }

    private func deleteAttachmentFiles(in message: CDMessage) {
        let attachments = (message.attachments as? Set<CDAttachment>) ?? []
        for attachment in attachments {
            attachmentFileStore.delete(relativePath: attachment.relativePath)
        }
    }
}
