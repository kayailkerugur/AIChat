//
//  AIChatView.swift
//  AIChatSDK
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Presentation/Chat
//
//  Message list + composer for the active conversation.
//  Auto-scrolls while streaming, shows an empty state for new chats,
//  and offers "regenerate" under the last assistant response.
//
//  UPDATED (sidebar step): previews rebuilt for the repository-backed
//  ChatViewModel init. View body unchanged.
//

import SwiftUI

public struct AIChatView: View {

    @State private var viewModel: ChatViewModel
    @Environment(\.aiChatTheme) private var environmentTheme
    @Environment(\.aiChatBranding) private var environmentBranding

    private let configuredTheme: AIChatTheme?
    private let configuredBranding: AIChatBranding?
    private let repositoryFiles: [RepositoryFile]
    private let selectedRepositoryFile: RepositoryFile?
    private let onSelectRepositoryFile: ((RepositoryFile) -> Void)?

    public init(
        viewModel: ChatViewModel,
        theme: AIChatTheme? = nil,
        branding: AIChatBranding? = nil,
        repositoryFiles: [RepositoryFile] = [],
        selectedRepositoryFile: RepositoryFile? = nil,
        onSelectRepositoryFile: ((RepositoryFile) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        configuredTheme = theme
        configuredBranding = branding
        self.repositoryFiles = repositoryFiles
        self.selectedRepositoryFile = selectedRepositoryFile
        self.onSelectRepositoryFile = onSelectRepositoryFile
    }

    private enum ScrollAnchor: Hashable { case bottom }

    public var body: some View {
        VStack(spacing: 0) {
            if let errorMessage = viewModel.errorMessage {
                ErrorBannerView(message: errorMessage) {
                    viewModel.dismissError()
                }
                .padding([.horizontal, .top], 12)
            }

            if viewModel.messages.isEmpty {
                emptyState
            } else {
                messageList
            }

            if let errorMessage = viewModel.errorMessage {
                ErrorBannerView(message: errorMessage) {
                    viewModel.dismissError()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }

            Divider()

            ComposerView(
                draft: Bindable(viewModel).draft,
                attachments: viewModel.pendingAttachments,
                isStreaming: viewModel.isStreaming,
                canSend: viewModel.canSend,
                onAddAttachment: { viewModel.addAttachment(from: $0) },
                onRemoveAttachment: { viewModel.removePendingAttachment(id: $0) },
                repositoryFiles: repositoryFiles,
                selectedRepositoryFile: selectedRepositoryFile,
                onSelectRepositoryFile: onSelectRepositoryFile,
                onSend: { viewModel.sendDraft() },
                onStop: { viewModel.stopStreaming() }
            )
        }
        .animation(.default, value: viewModel.errorMessage)
        .environment(\.aiChatTheme, theme)
        .environment(\.aiChatBranding, branding)
    }

    // MARK: - Pieces

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            onRetry: message.status == .failed
                                ? { viewModel.regenerateLastResponse() }
                                : nil,
                            onDeleteAttachment: { messageID, attachmentID in
                                viewModel.deleteAttachment(
                                    messageID: messageID,
                                    attachmentID: attachmentID
                                )
                            }
                        )
                    }

                    if viewModel.canRegenerate {
                        Button {
                            viewModel.regenerateLastResponse()
                        } label: {
                            Label("Yeniden üret", systemImage: "arrow.clockwise")
                                .font(theme.supportingFont)
                        }
                        .buttonStyle(.borderless)
                    }

                    // Invisible anchor to scroll to.
                    Color.clear
                        .frame(height: 1)
                        .id(ScrollAnchor.bottom)
                }
                .padding(16)
            }
            .onChange(of: viewModel.messages.last?.content) {
                // Follow the stream as text grows.
                proxy.scrollTo(ScrollAnchor.bottom, anchor: .bottom)
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation {
                    proxy.scrollTo(ScrollAnchor.bottom, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if let logo = branding.logo {
                logo
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 120, maxHeight: 48)
            }
            branding.emptyStateImage
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Yeni bir sohbete başlayın")
                .font(theme.titleFont)
            Text("Aşağıdaki alana ilk mesajınızı yazın. Markdown denemek için \"liste\", kod bloğu için \"kod\" kelimesini kullanabilirsiniz.")
                .font(theme.supportingFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var theme: AIChatTheme {
        configuredTheme ?? environmentTheme
    }

    private var branding: AIChatBranding {
        configuredBranding ?? environmentBranding
    }
}

// MARK: - Previews

/// Shared preview scaffolding: builds a ChatViewModel wired to an
/// in-memory repository and a mock provider with the given behavior.
@MainActor
private func makePreviewChatViewModel(
    ai behavior: MockAIProvider.Behavior
) -> ChatViewModel {
    let store = InMemoryChatRepository()
    let conversation = Conversation(
        title: "Yeni Sohbet",
        providerID: "mock",
        modelID: "mock-fast"
    )
    // Fire-and-forget is fine for previews; the store is in-memory.
    Task { try? await store.create(conversation) }

    return ChatViewModel(
        conversation: conversation,
        aiProvider: MockAIProvider(behavior: behavior),
        messageRepository: store,
        conversationRepository: store
    )
}

#Preview("Live mock stream") {
    AIChatView(
        viewModel: makePreviewChatViewModel(
            ai: .init(chunkDelay: .milliseconds(60))
        )
    )
    .frame(width: 640, height: 520)
}

#Preview("Mid-stream failure") {
    AIChatView(
        viewModel: makePreviewChatViewModel(
            ai: .init(failure: .network, failAfterChunks: 6)
        )
    )
    .frame(width: 640, height: 520)
}
