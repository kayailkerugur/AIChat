//
//  SidebarViewModel.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Presentation/Sidebar
//
//  UPDATED (error surfacing step): repository failures set
//  `errorMessage` instead of being swallowed (acceptance criterion 13).
//

import Foundation
import AIChatSDK
import Observation
import os

@MainActor
@Observable
final class SidebarViewModel {

    static let defaultTitle = "Yeni Sohbet"

    // MARK: - Observed state

    private(set) var conversations: [Conversation] = []
    private(set) var errorMessage: String?
    var selectedConversationID: UUID?
    var selectedProjectID: UUID?
    var searchText: String = ""

    var selectedConversation: Conversation? {
        guard let selectedConversationID else { return nil }
        return conversations.first { $0.id == selectedConversationID }
    }

    // MARK: - Dependencies

    private let conversationRepository: ConversationRepository
    private let usesProjects: Bool
    private let requiresProjectForNewConversation: Bool
    /// Closure, not a value: the preferred model (and thus provider)
    /// can change in Settings at any time — each new conversation
    /// reads it fresh.
    private let defaultModel: () -> AIModel
    private let logger = AppLogger.persistence

    /// MainWindowView sets this to drop the cached ChatViewModel
    /// (and cancel its stream) when a conversation is deleted.
    var onConversationDeleted: ((UUID) -> Void)?
    var onConversationMoved: ((UUID) -> Void)?

    init(
        conversationRepository: ConversationRepository,
        usesProjects: Bool,
        requiresProjectForNewConversation: Bool = false,
        defaultModel: @escaping () -> AIModel
    ) {
        self.conversationRepository = conversationRepository
        self.usesProjects = usesProjects
        self.requiresProjectForNewConversation =
            requiresProjectForNewConversation
        self.defaultModel = defaultModel
    }

    // MARK: - Intents

    func dismissError() {
        errorMessage = nil
    }

    func refresh() async {
        do {
            if !usesProjects {
                conversations = try await conversationRepository
                    .searchConversations(matching: searchText)
            } else if searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                conversations = try await conversationRepository
                    .conversations(inProject: selectedProjectID)
            } else {
                conversations = try await conversationRepository
                    .searchConversations(matching: searchText)
                    .filter { $0.projectID == selectedProjectID }
            }
        } catch {
            logger.error("refresh conversations failed: \(error.localizedDescription)")
            errorMessage = "Sohbetler yüklenemedi."
        }
    }

    func createConversation() async {
        if requiresProjectForNewConversation, selectedProjectID == nil {
            errorMessage = "Yeni sohbet için önce bir proje seçin."
            return
        }
        let model = defaultModel()
        guard !model.providerID.isEmpty, !model.id.isEmpty else {
            errorMessage = "Yeni sohbet için önce Ayarlar'dan bir sağlayıcı ve model ekleyin."
            return
        }
        let conversation = Conversation(
            title: Self.defaultTitle,
            providerID: model.providerID,
            modelID: model.id,
            projectID: usesProjects ? selectedProjectID : nil
        )
        do {
            try await conversationRepository.create(conversation)
            await refresh()
            selectedConversationID = conversation.id
        } catch {
            logger.error("create conversation failed: \(error.localizedDescription)")
            errorMessage = "Sohbet oluşturulamadı."
        }
    }

    func rename(conversationID: UUID, to title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await conversationRepository.rename(
                conversationID: conversationID, to: trimmed
            )
            await refresh()
        } catch {
            logger.error("rename conversation failed: \(error.localizedDescription)")
            errorMessage = "Sohbet yeniden adlandırılamadı."
        }
    }

    func delete(conversationID: UUID) async {
        do {
            try await conversationRepository.delete(conversationID: conversationID)
            onConversationDeleted?(conversationID)
            if selectedConversationID == conversationID {
                selectedConversationID = nil
            }
            await refresh()
        } catch {
            logger.error("delete conversation failed: \(error.localizedDescription)")
            errorMessage = "Sohbet silinemedi."
        }
    }

    func move(
        conversationID: UUID,
        toProject projectID: UUID?
    ) async {
        do {
            try await conversationRepository.move(
                conversationID: conversationID,
                toProject: projectID
            )
            onConversationMoved?(conversationID)
            if selectedConversationID == conversationID {
                selectedConversationID = nil
            }
            await refresh()
        } catch {
            logger.error(
                "move conversation failed: \(error.localizedDescription)"
            )
            errorMessage = "Sohbet başka projeye taşınamadı."
        }
    }
}
