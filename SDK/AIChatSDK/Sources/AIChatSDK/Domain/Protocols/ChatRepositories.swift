import Foundation

public protocol ConversationRepository: AnyObject, Sendable {
    func conversations() async throws -> [Conversation]
    func searchConversations(matching query: String) async throws -> [Conversation]
    func create(_ conversation: Conversation) async throws
    func rename(conversationID: UUID, to title: String) async throws
    func touch(conversationID: UUID, at date: Date) async throws
    func delete(conversationID: UUID) async throws
}

public protocol MessageRepository: AnyObject, Sendable {
    func messages(inConversation conversationID: UUID) async throws -> [ChatMessage]
    func append(_ message: ChatMessage, toConversation conversationID: UUID) async throws
    func update(_ message: ChatMessage, inConversation conversationID: UUID) async throws
    func deleteMessage(id: UUID, inConversation conversationID: UUID) async throws
}
