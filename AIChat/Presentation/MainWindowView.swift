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

import AppKit
import SwiftUI
import AIChatSDK

struct MainWindowView: View {

    let session: AuthSession
    let dependencies: AppDependencies

    @State private var sidebarViewModel: SidebarViewModel
    @State private var projectListViewModel: ProjectListViewModel
    @State private var chatViewModels = ChatViewModelCache()
    @State private var codeModeViewModels = CodeModeViewModelCache()
    @State private var projectCodeModeViewModels = CodeModeViewModelCache()
    @State private var isShowingSettings = false

    init(session: AuthSession, dependencies: AppDependencies) {
        self.session = session
        self.dependencies = dependencies
        let isCodeMode =
            dependencies.aiChatClient.configuration.mode == .code
        _sidebarViewModel = State(initialValue: SidebarViewModel(
            conversationRepository: dependencies.conversationRepository,
            usesProjects: true,
            requiresProjectForNewConversation: isCodeMode,
            defaultModel: { [registry = dependencies.aiProviders] in
                SettingsViewModel.preferredModel(in: registry)
            }
        ))
        _projectListViewModel = State(
            initialValue: ProjectListViewModel(
                repository: dependencies.projectRepository
            )
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: sidebarViewModel,
                projectViewModel: projectListViewModel,
                showsProjects: true,
                usesFolderTerminology:
                    dependencies.aiChatClient.configuration.mode == .standard,
                onCreateProject: createProject,
                onDeleteProject: deleteProject
            )
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
                    conversationView(
                        conversation: conversation,
                        viewModel: viewModel
                    )
                } else {
                    missingProviderView
                }
            } else if dependencies.aiChatClient.configuration.mode == .code,
                      let project = projectListViewModel.selectedProject,
                      let repositoryViewModel = projectViewModel(for: project) {
                ProjectDetailView(
                    project: project,
                    repositoryViewModel: repositoryViewModel,
                    conversationRepository:
                        dependencies.conversationRepository,
                    onSelectRepository: {
                        selectRepository(for: project)
                    },
                    onCreateConversation: {
                        Task {
                            await sidebarViewModel.createConversation()
                        }
                    },
                    onOpenConversation: { conversationID in
                        sidebarViewModel.selectedConversationID =
                            conversationID
                    }
                )
                .id(project.id)
            } else {
                noSelectionView
            }
        }
        .navigationTitle(
            isShowingSettings
                ? "Ayarlar"
                : (
                    sidebarViewModel.selectedConversation?.title
                        ?? projectListViewModel.selectedProject?.name
                        ?? "AI Chat"
                )
        )
        .onChange(of: sidebarViewModel.selectedConversationID) { _, newValue in
            // Picking a conversation in the sidebar leaves Settings.
            if newValue != nil {
                isShowingSettings = false
            }
        }
        .onChange(of: projectListViewModel.selectedProjectID) { _, newValue in
            sidebarViewModel.selectedProjectID = newValue
            sidebarViewModel.selectedConversationID = nil
            isShowingSettings = false
            Task { await sidebarViewModel.refresh() }
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
                codeModeViewModels.remove(id: id)
            }
            sidebarViewModel.onConversationMoved = { [chatViewModels] id in
                chatViewModels.remove(id: id)
                codeModeViewModels.remove(id: id)
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
            .accessibilityIdentifier("new-conversation")
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

    @ViewBuilder
    private func conversationView(
        conversation: Conversation,
        viewModel: ChatViewModel
    ) -> some View {
        switch dependencies.aiChatClient.configuration.mode {
        case .standard:
            ChatView(viewModel: viewModel)
                .id(conversation.id)
        case .code:
            if let codeModeViewModel = codeModeViewModel(for: conversation) {
                ChatView(viewModel: viewModel)
                .id(conversation.id)
                .task {
                    await codeModeViewModel.load()
                }
            } else {
                codeModeConfigurationErrorView
            }
        }
    }

    private var codeModeConfigurationErrorView: some View {
        ContentUnavailableView(
            "Code Mode yapılandırılamadı",
            systemImage: "folder.badge.questionmark",
            description: Text(
                "Developer konfigürasyonunda geçerli bir repository URL’si sağlayın."
            )
        )
    }

    private func createProject() {
        if dependencies.aiChatClient.configuration.mode == .standard {
            createConversationFolder()
            return
        }

        guard let url = chooseRepository(
            title: "Yeni Kod Projesi",
            prompt: "Proje Seç"
        ) else { return }

        Task {
            guard let project = await projectListViewModel.createProject(
                name: url.lastPathComponent
            ) else { return }
            do {
                try await dependencies.repositoryProvider?
                    .selectRepository(at: url, forProject: project.id)
                await projectViewModel(for: project)?.load()
            } catch {
                await projectViewModel(for: project)?.load()
            }
        }
    }

    private func createConversationFolder() {
        let alert = NSAlert()
        alert.messageText = "Yeni Klasör"
        alert.informativeText =
            "Sohbetlerinizi gruplamak için bir klasör adı girin."
        alert.addButton(withTitle: "Oluştur")
        alert.addButton(withTitle: "Vazgeç")

        let textField = NSTextField(
            frame: NSRect(x: 0, y: 0, width: 280, height: 24)
        )
        textField.placeholderString = "Klasör adı"
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = textField.stringValue
        Task {
            _ = await projectListViewModel.createProject(name: name)
        }
    }

    private func selectRepository(for project: AIChatProject) {
        guard let url = chooseRepository(
            title: "Proje Repository’sini Seç",
            prompt: "Repository Seç"
        ) else { return }

        Task {
            do {
                try await dependencies.repositoryProvider?
                    .selectRepository(at: url, forProject: project.id)
                await projectViewModel(for: project)?.load()
                for conversation in sidebarViewModel.conversations
                where conversation.projectID == project.id {
                    await codeModeViewModel(for: conversation)?.load()
                }
            } catch {
                await projectViewModel(for: project)?.load()
            }
        }
    }

    private func deleteProject(_ project: AIChatProject) {
        Task {
            var movedConversationIDs: [UUID] = []
            do {
                let conversations = try await dependencies
                    .conversationRepository
                    .conversations(inProject: project.id)
                for conversation in conversations {
                    try await dependencies.conversationRepository.move(
                        conversationID: conversation.id,
                        toProject: nil
                    )
                    movedConversationIDs.append(conversation.id)
                    chatViewModels.remove(id: conversation.id)
                    codeModeViewModels.remove(id: conversation.id)
                }

                let deleted = await projectListViewModel.delete(
                    projectID: project.id
                )
                guard deleted else { return }

                await dependencies.repositoryProvider?
                    .clearRepository(forProject: project.id)
                projectCodeModeViewModels.remove(id: project.id)
                sidebarViewModel.selectedProjectID = nil
                sidebarViewModel.selectedConversationID = nil
                await sidebarViewModel.refresh()
            } catch {
                for conversationID in movedConversationIDs {
                    try? await dependencies.conversationRepository.move(
                        conversationID: conversationID,
                        toProject: project.id
                    )
                }
                projectListViewModel.reportDeletionFailure()
            }
        }
    }

    private func chooseRepository(
        title: String,
        prompt: String
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message =
            "AI Chat’in salt okunur inceleyeceği Git proje klasörünü seçin."
        panel.prompt = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private func viewModel(for conversation: Conversation) -> ChatViewModel? {
        if let cached = chatViewModels.store[conversation.id] {
            return cached
        }
        let viewModel: ChatViewModel
        do {
            let codeModeViewModel = codeModeViewModel(for: conversation)
            viewModel = try dependencies.aiChatClient.makeChatViewModel(
                for: conversation,
                contextProvider: codeModeViewModel,
                onConversationMutated: { [sidebarViewModel] in
                    Task { await sidebarViewModel.refresh() }
                }
            )
        } catch {
            return nil
        }
        chatViewModels.store[conversation.id] = viewModel
        Task { await viewModel.load() }
        return viewModel
    }

    private func codeModeViewModel(
        for conversation: Conversation
    ) -> CodeModeViewModel? {
        guard dependencies.aiChatClient.configuration.mode == .code else {
            return nil
        }
        if let cached = codeModeViewModels.store[conversation.id] {
            return cached
        }
        guard let viewModel = try? dependencies.aiChatClient
            .makeCodeModeViewModel(for: conversation) else {
            return nil
        }
        codeModeViewModels.store[conversation.id] = viewModel
        return viewModel
    }

    private func projectViewModel(
        for project: AIChatProject
    ) -> CodeModeViewModel? {
        if let cached = projectCodeModeViewModels.store[project.id] {
            return cached
        }
        guard let viewModel = try? dependencies.aiChatClient
            .makeCodeModeViewModel(for: project) else {
            return nil
        }
        projectCodeModeViewModels.store[project.id] = viewModel
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

/// Code Mode state is conversation-scoped so repository selection, selected
/// diff and file context never leak into another chat.
@MainActor
final class CodeModeViewModelCache {
    var store: [UUID: CodeModeViewModel] = [:]

    func remove(id: UUID) {
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
