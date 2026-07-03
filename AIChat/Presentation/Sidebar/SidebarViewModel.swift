//
//  SidebarViewModel.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Owns the conversation list: load, create, rename, delete, search
//  and the current selection. Talks to ConversationRepository only —
//  it has no idea whether the store is in-memory or Core Data.
//

import Foundation
import Observation

@MainActor
@Observable
final class SidebarViewModel {

    static let defaultTitle = "Yeni Sohbet"

    // MARK: - Observed state

    private(set) var conversations: [Conversation] = []
    var selectedConversationID: UUID?
    var searchText: String = ""

    var selectedConversation: Conversation? {
        guard let selectedConversationID else { return nil }
        return conversations.first { $0.id == selectedConversationID }
    }

    // MARK: - Dependencies

    private let conversationRepository: ConversationRepository
    private let defaultProviderID: String
    private let defaultModelID: String

    /// MainWindowView sets this to drop the cached ChatViewModel
    /// (and cancel its stream) when a conversation is deleted.
    var onConversationDeleted: ((UUID) -> Void)?

    init(
        conversationRepository: ConversationRepository,
        defaultProviderID: String,
        defaultModelID: String
    ) {
        self.conversationRepository = conversationRepository
        self.defaultProviderID = defaultProviderID
        self.defaultModelID = defaultModelID
    }

    // MARK: - Intents

    func refresh() async {
        do {
            conversations = try await conversationRepository
                .searchConversations(matching: searchText)
        } catch {
            // In-memory store never throws; Core Data phase will surface
            // this through a user-visible error state.
            conversations = []
        }
    }

    func createConversation() async {
        let conversation = Conversation(
            title: Self.defaultTitle,
            providerID: defaultProviderID,
            modelID: defaultModelID
        )
        try? await conversationRepository.create(conversation)
        await refresh()
        selectedConversationID = conversation.id
    }

    func rename(conversationID: UUID, to title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? await conversationRepository.rename(conversationID: conversationID, to: trimmed)
        await refresh()
    }

    func delete(conversationID: UUID) async {
        try? await conversationRepository.delete(conversationID: conversationID)
        onConversationDeleted?(conversationID)
        if selectedConversationID == conversationID {
            selectedConversationID = nil
        }
        await refresh()
    }
}
