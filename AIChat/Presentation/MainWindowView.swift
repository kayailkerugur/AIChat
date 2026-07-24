//
//  MainWindowView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Presentation/ (main window)
//
//  UPDATED (sidebar step): NavigationSplitView with the conversation
//  sidebar on the left and the active chat on the right.
//
//  ChatViewModels are cached per conversation in a plain (non-observed)
//  holder so that:
//  - switching conversations does NOT cancel an in-flight stream,
//  - scroll/draft state survives selection changes,
//  - creating a VM inside `body` doesn't mutate observed @State.
//

import SwiftUI
import AIChatSDK

struct MainWindowView: View {

    let session: AuthSession
    let dependencies: AppDependencies

    @State private var sidebarViewModel: SidebarViewModel
    @State private var chatViewModels = ChatViewModelCache()
    @State private var isShowingSettings = false

    init(session: AuthSession, dependencies: AppDependencies) {
        self.session = session
        self.dependencies = dependencies
        _sidebarViewModel = State(initialValue: SidebarViewModel(
            conversationRepository: dependencies.conversationRepository,
            defaultModel: { [registry = dependencies.aiProviders] in
                SettingsViewModel.preferredModel(in: registry)
            }
        ))
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: sidebarViewModel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 320)
        } detail: {
            if isShowingSettings {
                // Settings renders IN the detail column, like a chat
                // screen (team review, item 1) — not as a modal sheet.
                SettingsView(
                    viewModel: SettingsViewModel(
                        registry: dependencies.aiProviders,
                        providerConfigurationService: dependencies.providerConfigurationService,
                        authService: dependencies.authService
                    ),
                    session: session
                )
            } else if let conversation = sidebarViewModel.selectedConversation {
                if let viewModel = viewModel(for: conversation) {
                    ChatView(viewModel: viewModel)
                        .id(conversation.id) // fresh view identity per conversation
                } else {
                    missingProviderView
                }
            } else {
                noSelectionView
            }
        }
        .navigationTitle(
            isShowingSettings
                ? "Ayarlar"
                : (sidebarViewModel.selectedConversation?.title ?? "AI Chat")
        )
        .onChange(of: sidebarViewModel.selectedConversationID) { _, newValue in
            // Picking a conversation in the sidebar leaves Settings.
            if newValue != nil {
                isShowingSettings = false
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    isShowingSettings.toggle()
                } label: {
                    Label("Ayarlar", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command) // macOS convention
                .accessibilityLabel(isShowingSettings ? "Ayarlardan çık" : "Ayarları aç")
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    if let email = session.email {
                        Text(email)
                    }
                    Divider()
                    Button("Çıkış Yap") {
                        Task { await dependencies.authService.logout() }
                    }
                } label: {
                    Label(
                        session.displayName ?? "Profil",
                        systemImage: "person.crop.circle"
                    )
                }
            }
        }
        .task {
            sidebarViewModel.onConversationDeleted = { [chatViewModels] id in
                chatViewModels.remove(id: id) // also cancels its stream
            }
        }
    }

    // MARK: - Pieces

    private var noSelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Bir sohbet seçin veya yeni bir tane oluşturun")
                .foregroundStyle(.secondary)
            Button("Yeni Sohbet (⌘N)") {
                Task { await sidebarViewModel.createConversation() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var missingProviderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Bu sohbetin sağlayıcısı bulunamadı")
                .foregroundStyle(.secondary)
            Button("Ayarları Aç") {
                isShowingSettings = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func viewModel(for conversation: Conversation) -> ChatViewModel? {
        if let cached = chatViewModels.store[conversation.id] {
            return cached
        }
        // Resolve the provider this conversation was created with —
        // the registry's fallback covers conversations whose provider
        // is no longer registered.
        guard let provider = dependencies.aiProviders
            .resolvedProvider(forID: conversation.providerID)
        else { return nil }

        let viewModel = ChatViewModel(
            conversation: conversation,
            aiProvider: provider,
            messageRepository: dependencies.messageRepository,
            conversationRepository: dependencies.conversationRepository,
            onConversationMutated: { [sidebarViewModel] in
                Task { await sidebarViewModel.refresh() }
            }
        )
        chatViewModels.store[conversation.id] = viewModel
        Task { await viewModel.load() }
        return viewModel
    }
}

/// Plain reference-type cache. Deliberately NOT @Observable:
/// mutating it inside `body` must not invalidate the view.
@MainActor
final class ChatViewModelCache {
    var store: [UUID: ChatViewModel] = [:]

    func remove(id: UUID) {
        store[id]?.stopStreaming()
        store.removeValue(forKey: id)
    }
}

#Preview {
    MainWindowView(
        session: AuthSession(
            userID: "preview",
            displayName: "Test Kullanıcısı",
            email: "test@example.com",
            providerID: "mock",
            expiresAt: nil
        ),
        dependencies: .makePreview()
    )
    .frame(width: 900, height: 600)
}
