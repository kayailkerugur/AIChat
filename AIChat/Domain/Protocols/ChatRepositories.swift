//
//  ChatRepositories.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Persistence contracts for conversations and messages.
//  ViewModels depend on these; today an in-memory implementation
//  satisfies them, in Days 11–15 a Core Data one replaces it with
//  ZERO changes above this line of the architecture.
//
//  All methods are `async throws` even though the in-memory version
//  can't fail — the contract is written for the real implementation
//  (background contexts, save errors), not the temporary one.
//

import Foundation

protocol ConversationRepository: AnyObject {
    /// All conversations, sorted by updatedAt descending (newest first).
    func conversations() async throws -> [Conversation]

    /// Conversations whose title OR message contents match the query.
    /// Empty/whitespace query behaves like `conversations()`.
    func searchConversations(matching query: String) async throws -> [Conversation]

    func create(_ conversation: Conversation) async throws

    func rename(conversationID: UUID, to title: String) async throws

    /// Bumps updatedAt so the sidebar ordering stays correct.
    func touch(conversationID: UUID, at date: Date) async throws

    /// Deleting a conversation also deletes its messages
    /// (cascade — enforced by the store).
    func delete(conversationID: UUID) async throws
}

protocol MessageRepository: AnyObject {
    /// Messages of a conversation, oldest first.
    func messages(inConversation conversationID: UUID) async throws -> [ChatMessage]

    func append(_ message: ChatMessage, toConversation conversationID: UUID) async throws

    /// Upserts by message.id — used to finalize streaming placeholders.
    func update(_ message: ChatMessage, inConversation conversationID: UUID) async throws

    func deleteMessage(id: UUID, inConversation conversationID: UUID) async throws
}
