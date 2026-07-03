//
//  ChatViewModel.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//  UPDATED (sidebar step): now conversation-scoped and repository-backed.
//  Messages are loaded from and persisted through MessageRepository, so
//  the Core Data phase plugs in with zero changes here beyond DI.
//
//  Streaming lifecycle (unchanged):
//    send → persist user message → persist assistant placeholder (.streaming)
//         → accumulate deltas in memory → persist final state on terminal
//
//  Design note: deltas are NOT written to the repository one by one —
//  only the terminal state is. This keeps the Core Data implementation
//  cheap (one update per response instead of hundreds) at the cost of
//  a crash mid-stream leaving a stuck `.streaming` row, which the spec
//  already requires us to repair at launch ("yarım kalmış stream
//  kayıtları güvenli duruma alınmalı") — handled in the Core Data phase.
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {

    // MARK: - State observed by the UI

    private(set) var messages: [ChatMessage] = []
    private(set) var isStreaming = false

    /// Composer text. Bindable from the view.
    var draft: String = ""

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    var canRegenerate: Bool {
        !isStreaming && messages.contains { $0.role == .assistant }
    }

    // MARK: - Dependencies

    let conversation: Conversation

    private let aiProvider: AIProvider
    private let messageRepository: MessageRepository
    private let conversationRepository: ConversationRepository
    /// Called after anything that changes sidebar-visible state
    /// (title, updatedAt) so the list can refresh its ordering.
    private let onConversationMutated: () -> Void

    private var streamTask: Task<Void, Never>?

    init(
        conversation: Conversation,
        aiProvider: AIProvider,
        messageRepository: MessageRepository,
        conversationRepository: ConversationRepository,
        onConversationMutated: @escaping () -> Void = {}
    ) {
        self.conversation = conversation
        self.aiProvider = aiProvider
        self.messageRepository = messageRepository
        self.conversationRepository = conversationRepository
        self.onConversationMutated = onConversationMutated
    }

    // MARK: - Lifecycle

    /// Loads persisted messages. Called once when the conversation opens.
    func load() async {
        messages = (try? await messageRepository
            .messages(inConversation: conversation.id)) ?? []
    }

    // MARK: - User intents

    func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        draft = ""
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        Task {
            // In-memory store can't fail; the Core Data implementation will
            // surface save errors through a user-visible state (spec rule:
            // save errors must not be swallowed).
            try? await messageRepository.append(
                userMessage, toConversation: conversation.id
            )
            await autoTitleIfNeeded(from: text)
            await touchConversation()
        }

        startStreaming()
    }

    func stopStreaming() {
        aiProvider.cancelCurrentRequest()
        streamTask?.cancel()
    }

    /// Removes the last assistant message (completed, failed or cancelled)
    /// and asks again with the same history. Serves both "regenerate"
    /// and "retry after failure".
    func regenerateLastResponse() {
        guard !isStreaming,
              let index = messages.lastIndex(where: { $0.role == .assistant })
        else { return }

        let removed = messages.remove(at: index)
        Task {
            try? await messageRepository.deleteMessage(
                id: removed.id, inConversation: conversation.id
            )
        }
        startStreaming()
    }

    // MARK: - Streaming core

    private func startStreaming() {
        let assistantID = UUID()
        let placeholder = ChatMessage(
            id: assistantID,
            role: .assistant,
            content: "",
            status: .streaming
        )
        messages.append(placeholder)
        isStreaming = true

        // History snapshot: everything up to (not including) the placeholder.
        let history = Array(messages.dropLast())
        let request = ChatRequest(messages: history, modelID: conversation.modelID)

        streamTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isStreaming = false
                self.streamTask = nil
            }

            // Persist the placeholder so a crash leaves a repairable row.
            try? await self.messageRepository.append(
                placeholder, toConversation: self.conversation.id
            )

            do {
                for try await event in self.aiProvider.stream(request: request) {
                    switch event {
                    case .textDelta(let delta):
                        self.mutateMessage(id: assistantID) { $0.content += delta }
                    case .usage:
                        break // surfaced later if we add a token counter UI
                    case .completed:
                        self.mutateMessage(id: assistantID) { $0.status = .completed }
                    }
                }
            } catch let error as AIError {
                self.applyFailure(error, to: assistantID)
            } catch is CancellationError {
                self.applyFailure(.cancelled, to: assistantID)
            } catch {
                self.applyFailure(
                    .unknown(debugDescription: String(describing: error)),
                    to: assistantID
                )
            }

            // Persist the final state (content + terminal status) once.
            if let final = self.messages.first(where: { $0.id == assistantID }) {
                try? await self.messageRepository.update(
                    final, inConversation: self.conversation.id
                )
            }
            await self.touchConversation()
        }
    }

    private func applyFailure(_ error: AIError, to assistantID: UUID) {
        mutateMessage(id: assistantID) { message in
            if error == .cancelled {
                // User's own action: keep partial text, no error banner.
                message.status = .cancelled
            } else {
                message.status = .failed
                message.errorDescription = error.errorDescription
            }
        }
    }

    private func mutateMessage(id: UUID, _ mutate: (inout ChatMessage) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        mutate(&messages[index])
    }

    // MARK: - Conversation bookkeeping

    /// First user message becomes the conversation title (like ChatGPT),
    /// but only while the title is still the default one — a manual
    /// rename is never overwritten.
    private func autoTitleIfNeeded(from text: String) async {
        guard conversation.title == SidebarViewModel.defaultTitle else { return }
        let title = String(text.prefix(40))
        try? await conversationRepository.rename(
            conversationID: conversation.id, to: title
        )
        onConversationMutated()
    }

    private func touchConversation() async {
        try? await conversationRepository.touch(
            conversationID: conversation.id, at: Date()
        )
        onConversationMutated()
    }
}
