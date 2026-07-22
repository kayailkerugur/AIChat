//
//  InMemoryChatRepository.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Temporary store satisfying both repository protocols until the
//  Core Data phase (Days 11–15). Also stays useful forever after:
//  ViewModel unit tests and SwiftUI previews run against this instead
//  of a persistent store.
//
//  Mimics Core Data semantics on purpose:
//  - delete(conversationID:) cascades to messages
//  - conversations() sorts by updatedAt descending
//  - search matches title and message contents (case-insensitive)
//

import Foundation

@MainActor
public final class InMemoryChatRepository: ConversationRepository, MessageRepository {

    private var conversationsByID: [UUID: Conversation] = [:]
    private var messagesByConversation: [UUID: [ChatMessage]] = [:]

    public init() {}

    // MARK: - ConversationRepository

    public func conversations() async throws -> [Conversation] {
        conversationsByID.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func searchConversations(matching query: String) async throws -> [Conversation] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try await conversations() }

        return try await conversations().filter { conversation in
            if conversation.title.localizedCaseInsensitiveContains(trimmed) {
                return true
            }
            let messages = messagesByConversation[conversation.id] ?? []
            return messages.contains {
                $0.content.localizedCaseInsensitiveContains(trimmed)
            }
        }
    }

    public func create(_ conversation: Conversation) async throws {
        conversationsByID[conversation.id] = conversation
        messagesByConversation[conversation.id] = []
    }

    public func rename(conversationID: UUID, to title: String) async throws {
        conversationsByID[conversationID]?.title = title
    }

    public func touch(conversationID: UUID, at date: Date) async throws {
        conversationsByID[conversationID]?.updatedAt = date
    }

    public func delete(conversationID: UUID) async throws {
        conversationsByID.removeValue(forKey: conversationID)
        // Cascade — same behavior the Core Data delete rule will enforce.
        messagesByConversation.removeValue(forKey: conversationID)
    }

    // MARK: - MessageRepository

    public func messages(inConversation conversationID: UUID) async throws -> [ChatMessage] {
        messagesByConversation[conversationID] ?? []
    }

    public func append(_ message: ChatMessage, toConversation conversationID: UUID) async throws {
        messagesByConversation[conversationID, default: []].append(message)
    }

    public func update(_ message: ChatMessage, inConversation conversationID: UUID) async throws {
        guard var messages = messagesByConversation[conversationID],
              let index = messages.firstIndex(where: { $0.id == message.id })
        else { return }
        messages[index] = message
        messagesByConversation[conversationID] = messages
    }

    public func deleteMessage(id: UUID, inConversation conversationID: UUID) async throws {
        messagesByConversation[conversationID]?.removeAll { $0.id == id }
    }
}
