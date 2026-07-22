//
//  ChatViewModel.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  UPDATED (error surfacing step): persistence failures are no longer
//  swallowed with try? — they are logged AND surfaced to the user via
//  `errorMessage` (acceptance criterion 13).
//
//  Error policy:
//  - User DATA at risk (message load/save)  → banner + log
//  - Cosmetic metadata (title, updatedAt)   → log only; a banner for
//    a failed timestamp bump would be noise, no user data is lost
//
//  Streaming deliberately CONTINUES even if persistence fails — the
//  user still gets their answer; the banner explains that history
//  may be incomplete.
//

import Foundation
import Observation

@MainActor
@Observable
public final class ChatViewModel {

    // MARK: - State observed by the UI

    public private(set) var messages: [ChatMessage] = []
    public private(set) var isStreaming = false
    public private(set) var errorMessage: String?

    /// Composer text. Bindable from the view.
    public var draft: String = ""
    public var pendingAttachments: [ChatAttachment] = []

    public var canSend: Bool {
        (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty)
            && !isStreaming
    }

    public var canRegenerate: Bool {
        !isStreaming && messages.contains { $0.role == .assistant }
    }

    // MARK: - Dependencies

    public let conversation: Conversation

    private let aiProvider: any AIProvider
    private let messageRepository: MessageRepository
    private let conversationRepository: ConversationRepository
    private let onConversationMutated: @MainActor () -> Void
    private let defaultConversationTitle: String
    private let logger = SDKLogger.persistence

    private var streamTask: Task<Void, Never>?

    public init(
        conversation: Conversation,
        aiProvider: any AIProvider,
        messageRepository: MessageRepository,
        conversationRepository: ConversationRepository,
        defaultConversationTitle: String = "Yeni Sohbet",
        onConversationMutated: @escaping @MainActor () -> Void = {}
    ) {
        self.conversation = conversation
        self.aiProvider = aiProvider
        self.messageRepository = messageRepository
        self.conversationRepository = conversationRepository
        self.defaultConversationTitle = defaultConversationTitle
        self.onConversationMutated = onConversationMutated
    }

    // MARK: - Lifecycle

    public func load() async {
        do {
            messages = try await messageRepository
                .messages(inConversation: conversation.id)
        } catch {
            logger.error("load messages failed: \(error.localizedDescription)")
            errorMessage = "Sohbet geçmişi yüklenemedi."
        }
    }

    public func dismissError() {
        errorMessage = nil
    }

    // MARK: - User intents

    public func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = pendingAttachments
        guard (!text.isEmpty || !attachments.isEmpty), !isStreaming else { return }
        guard aiProvider.supportsImages || !attachments.contains(where: { $0.kind == .image }) else {
            errorMessage = "Seçili sağlayıcı görsel eklerini desteklemiyor. Görsel destekli farklı bir model veya sağlayıcı seçin."
            return
        }

        draft = ""
        pendingAttachments = []
        let userMessage = ChatMessage(
            role: .user,
            content: text,
            attachments: attachments
        )
        messages.append(userMessage)

        Task {
            do {
                try await messageRepository.append(
                    userMessage, toConversation: conversation.id
                )
            } catch {
                logger.error("append user message failed: \(error.localizedDescription)")
                errorMessage = "Mesaj kaydedilemedi. Sohbet geçmişiniz eksik olabilir."
            }
            await autoTitleIfNeeded(from: text)
            await touchConversation()
        }

        startStreaming()
    }

    public func addAttachment(from url: URL) {
        do {
            let attachment = try AttachmentLoader.load(from: url)
            pendingAttachments.append(attachment)
        } catch {
            logger.error("attachment load failed: \(error.localizedDescription)")
            errorMessage = "Dosya eklenemedi."
        }
    }

    public func removePendingAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    public func deleteAttachment(messageID: UUID, attachmentID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }

        let originalMessage = messages[index]
        messages[index].attachments.removeAll { $0.id == attachmentID }
        let updatedMessage = messages[index]

        Task {
            do {
                try await messageRepository.update(
                    updatedMessage,
                    inConversation: conversation.id
                )
            } catch {
                logger.error("delete attachment failed: \(error.localizedDescription)")
                if let currentIndex = messages.firstIndex(where: { $0.id == messageID }) {
                    messages[currentIndex] = originalMessage
                }
                errorMessage = "Ek silinemedi."
            }
        }
    }

    public func stopStreaming() {
        aiProvider.cancelCurrentRequest()
        streamTask?.cancel()
    }

    /// Removes the last assistant message (completed, failed or cancelled)
    /// and asks again with the same history. Serves both "regenerate"
    /// and "retry after failure".
    public func regenerateLastResponse() {
        guard !isStreaming,
              let index = messages.lastIndex(where: { $0.role == .assistant })
        else { return }

        let removed = messages.remove(at: index)
        Task {
            do {
                try await messageRepository.deleteMessage(
                    id: removed.id, inConversation: conversation.id
                )
            } catch {
                logger.error("delete for regenerate failed: \(error.localizedDescription)")
                errorMessage = "Önceki yanıt silinemedi. Geçmişte yinelenen kayıt kalabilir."
            }
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

        // Resilience: a conversation may carry a modelID this provider
        // doesn't know (e.g. chats created back when MockAIProvider was
        // active carry "mock-fast"). Fall back to the provider's first
        // model instead of guaranteed 404s.
        let modelID = aiProvider.supportedModels.contains(where: { $0.id == conversation.modelID })
            ? conversation.modelID
            : (aiProvider.supportedModels.first?.id ?? conversation.modelID)

        let request = ChatRequest(messages: history, modelID: modelID)

        streamTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isStreaming = false
                self.streamTask = nil
            }

            // Persist the placeholder so a crash leaves a repairable row.
            do {
                try await self.messageRepository.append(
                    placeholder, toConversation: self.conversation.id
                )
            } catch {
                self.logger.error("append placeholder failed: \(error.localizedDescription)")
                self.errorMessage = "Yanıt kaydedilemedi. Sohbet geçmişiniz eksik olabilir."
                // Streaming continues: the user still gets the answer.
            }

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
                // Subtle but important: when the CONSUMING task is cancelled,
                // AsyncThrowingStream ends iteration silently (returns nil)
                // instead of throwing CancellationError — only producer-side
                // cancellation throws through the stream. If the loop ended
                // without a terminal event, resolve the placeholder here so
                // the message can never be left stuck in `.streaming`.
                self.finishIfStillStreaming(assistantID: assistantID)
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
                do {
                    try await self.messageRepository.update(
                        final, inConversation: self.conversation.id
                    )
                } catch {
                    self.logger.error("finalize message failed: \(error.localizedDescription)")
                    self.errorMessage = "Yanıt kaydedilemedi. Sohbet geçmişiniz eksik olabilir."
                }
            }
            await self.touchConversation()
        }
    }

    /// Resolves a placeholder that reached the end of iteration without a
    /// terminal event — which only happens on consumer-side cancellation.
    private func finishIfStillStreaming(assistantID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == assistantID }),
              !messages[index].status.isTerminal
        else { return }
        applyFailure(.cancelled, to: assistantID)
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

    // MARK: - Conversation bookkeeping (metadata: log-only on failure)

    /// First user message becomes the conversation title (like ChatGPT),
    /// but only while the title is still the default one — a manual
    /// rename is never overwritten.
    private func autoTitleIfNeeded(from text: String) async {
        guard conversation.title == defaultConversationTitle else { return }
        let title = String(text.prefix(40))
        do {
            try await conversationRepository.rename(
                conversationID: conversation.id, to: title
            )
        } catch {
            // Cosmetic metadata — no user data lost, banner would be noise.
            logger.error("auto-title failed: \(error.localizedDescription)")
        }
        onConversationMutated()
    }

    private func touchConversation() async {
        do {
            try await conversationRepository.touch(
                conversationID: conversation.id, at: Date()
            )
        } catch {
            logger.error("touch conversation failed: \(error.localizedDescription)")
        }
        onConversationMutated()
    }
}
