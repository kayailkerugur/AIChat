import Foundation

public enum MessageRole: String, Codable, CaseIterable, Sendable {
    case user
    case assistant
    case system
}

public enum MessageStatus: String, Codable, Sendable {
    case sending
    case streaming
    case completed
    case failed
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: return true
        case .sending, .streaming: return false
        }
    }
}

public struct ChatMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let role: MessageRole
    public var content: String
    public var attachments: [ChatAttachment]
    public let createdAt: Date
    public var status: MessageStatus
    public var errorDescription: String?

    public init(
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
