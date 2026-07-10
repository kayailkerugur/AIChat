//
//  ChatMessage.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Domain/Models
//
//  Provider-agnostic chat message model. Mirrors the planned Core Data
//  Message entity field-by-field, so mapping stays trivial in Days 11–15.
//  UI and providers both speak THIS type — never provider DTOs,
//  never NSManagedObjects.
//

import Foundation

enum MessageRole: String, Codable, CaseIterable {
    case user
    case assistant
    case system
}

/// Lifecycle of a message. Matches the spec's Message.status column.
enum MessageStatus: String, Codable {
    /// User message created, request not yet dispatched.
    case sending
    /// Assistant message currently receiving deltas.
    case streaming
    /// Terminal: finished successfully.
    case completed
    /// Terminal: provider/network error. `errorDescription` explains it.
    case failed
    /// Terminal: user pressed stop. Partial content is kept.
    case cancelled

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: return true
        case .sending, .streaming: return false
        }
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    var attachments: [ChatAttachment]
    let createdAt: Date
    var status: MessageStatus
    /// Safe, user-facing error summary. Raw payloads never end up here.
    var errorDescription: String?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        attachments: [ChatAttachment] = [],
        createdAt: Date = Date(),
        status: MessageStatus = .completed,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.attachments = attachments
        self.createdAt = createdAt
        self.status = status
        self.errorDescription = errorDescription
    }
}
