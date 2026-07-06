//
//  ChatView.swift
//  AIChat
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

struct ChatView: View {

    @State private var viewModel: ChatViewModel

    init(viewModel: ChatViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private enum ScrollAnchor: Hashable { case bottom }

    var body: some View {
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
                isStreaming: viewModel.isStreaming,
                canSend: viewModel.canSend,
                onSend: { viewModel.sendDraft() },
                onStop: { viewModel.stopStreaming() }
            )
        }
        .animation(.default, value: viewModel.errorMessage)
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
                                : nil
                        )
                    }

                    if viewModel.canRegenerate {
                        Button {
                            viewModel.regenerateLastResponse()
                        } label: {
                            Label("Yeniden üret", systemImage: "arrow.clockwise")
                                .font(.callout)
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
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Yeni bir sohbete başlayın")
                .font(.title3)
            Text("Aşağıdaki alana ilk mesajınızı yazın. Markdown denemek için \"liste\", kod bloğu için \"kod\" kelimesini kullanabilirsiniz.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        title: SidebarViewModel.defaultTitle,
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
    ChatView(
        viewModel: makePreviewChatViewModel(
            ai: .init(chunkDelay: .milliseconds(60))
        )
    )
    .frame(width: 640, height: 520)
}

#Preview("Mid-stream failure") {
    ChatView(
        viewModel: makePreviewChatViewModel(
            ai: .init(failure: .network, failAfterChunks: 6)
        )
    )
    .frame(width: 640, height: 520)
}
