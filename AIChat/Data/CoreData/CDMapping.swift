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

    func toDomain() -> ChatMessage {
        ChatMessage(
            id: id ?? UUID(),
            // Unknown role/status strings (corrupted or from a future
            // schema) fall back to the safest terminal interpretation.
            role: MessageRole(rawValue: role ?? "") ?? .assistant,
            content: content ?? "",
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
}
