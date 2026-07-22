//
//  CDMapping.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//

import Foundation
import CoreData

// MARK: - CDConversation

extension CDConversation {

    func toDomain() -> Conversation {
        Conversation(
            id: id ?? UUID(),
            title: title ?? "",
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            providerID: providerID ?? "",
            modelID: modelID ?? ""
        )
    }

    func apply(_ conversation: Conversation) {
        id = conversation.id
        title = conversation.title
        createdAt = conversation.createdAt
        updatedAt = conversation.updatedAt
        providerID = conversation.providerID
        modelID = conversation.modelID
    }
}

// MARK: - CDMessage

extension CDMessage {

    func toDomain(attachmentFileStore: AttachmentFileStore) -> ChatMessage {
        ChatMessage(
            id: id ?? UUID(),
            // Unknown role/status strings (corrupted or from a future
            // schema) fall back to the safest terminal interpretation.
            role: MessageRole(rawValue: role ?? "") ?? .assistant,
            content: content ?? "",
            attachments: mappedAttachments(using: attachmentFileStore),
            createdAt: createdAt ?? Date(),
            status: MessageStatus(rawValue: status ?? "") ?? .failed,
            errorDescription: errorDescription
        )
    }

    func apply(_ message: ChatMessage) {
        id = message.id
        role = message.role.rawValue
        content = message.content
        createdAt = message.createdAt
        status = message.status.rawValue
        errorDescription = message.errorDescription
    }

    func mappedAttachments(using attachmentFileStore: AttachmentFileStore) -> [ChatAttachment] {
        let rows = (attachments as? Set<CDAttachment>) ?? []
        return rows
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { $0.toDomain(attachmentFileStore: attachmentFileStore) }
    }
}

// MARK: - CDAttachment

extension CDAttachment {

    func toDomain(attachmentFileStore: AttachmentFileStore) -> ChatAttachment {
        let attachmentData = relativePath
            .flatMap { attachmentFileStore.read(relativePath: $0) }
            ?? data
            ?? Data()

        return ChatAttachment(
            id: id ?? UUID(),
            fileName: fileName ?? "Dosya",
            mimeType: mimeType ?? "application/octet-stream",
            kind: ChatAttachmentKind(rawValue: kind ?? "") ?? .document,
            data: attachmentData,
            extractedText: extractedText
        )
    }

    func apply(_ attachment: ChatAttachment, sortIndex: Int32, relativePath: String?) {
        id = attachment.id
        fileName = attachment.fileName
        mimeType = attachment.mimeType
        kind = attachment.kind.rawValue
        data = nil
        self.relativePath = relativePath
        extractedText = attachment.extractedText
        self.sortIndex = sortIndex
    }
}
