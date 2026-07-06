//
//  SidebarView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Conversation list with search, new-chat (⌘N), and per-row
//  context menu for rename/delete — the macOS-native way to expose
//  these actions (right-click), per the spec's screen table.
//

import SwiftUI

struct SidebarView: View {

    @Bindable var viewModel: SidebarViewModel

    // Rename alert state
    @State private var renamingConversation: Conversation?
    @State private var renameText = ""

    var body: some View {
        List(selection: $viewModel.selectedConversationID) {
            ForEach(viewModel.conversations) { conversation in
                row(for: conversation)
                    .tag(conversation.id)
                    .contextMenu {
                        Button("Yeniden Adlandır") {
                            renameText = conversation.title
                            renamingConversation = conversation
                        }
                        Divider()
                        Button("Sil", role: .destructive) {
                            Task { await viewModel.delete(conversationID: conversation.id) }
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .searchable(
            text: $viewModel.searchText,
            placement: .sidebar,
            prompt: "Sohbetlerde ara"
        )
        .safeAreaInset(edge: .bottom) {
            if let errorMessage = viewModel.errorMessage {
                ErrorBannerView(message: errorMessage) {
                    viewModel.dismissError()
                }
                .padding(8)
            }
        }
        .animation(.default, value: viewModel.errorMessage)
        .onChange(of: viewModel.searchText) {
            Task { await viewModel.refresh() }
        }
        .overlay {
            if viewModel.conversations.isEmpty {
                emptyOverlay
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await viewModel.createConversation() }
                } label: {
                    Label("Yeni Sohbet", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityLabel("Yeni sohbet oluştur")
            }
        }
        .alert(
            "Sohbeti Yeniden Adlandır",
            isPresented: Binding(
                get: { renamingConversation != nil },
                set: { if !$0 { renamingConversation = nil } }
            )
        ) {
            TextField("Başlık", text: $renameText)
            Button("Vazgeç", role: .cancel) {}
            Button("Kaydet") {
                if let conversation = renamingConversation {
                    Task {
                        await viewModel.rename(
                            conversationID: conversation.id,
                            to: renameText
                        )
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let error = viewModel.errorMessage {
                ErrorBannerView(message: error) {
                    viewModel.dismissError()
                }
                .padding(8)
            }
        }
        .task { await viewModel.refresh() }
    }

    // MARK: - Pieces

    private func row(for conversation: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(conversation.title)
                .lineLimit(1)
            Text(conversation.updatedAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var emptyOverlay: some View {
        VStack(spacing: 8) {
            if viewModel.searchText.isEmpty {
                Text("Henüz sohbet yok")
                    .foregroundStyle(.secondary)
                Text("⌘N ile yeni bir sohbet başlatın")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Sonuç bulunamadı")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
