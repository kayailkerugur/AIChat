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
import AIChatSDK

struct SidebarView: View {

    @Bindable var viewModel: SidebarViewModel
    @Bindable var projectViewModel: ProjectListViewModel
    let showsProjects: Bool
    let usesFolderTerminology: Bool
    let onCreateProject: () -> Void
    let onDeleteProject: (AIChatProject) -> Void

    // Rename alert state
    @State private var renamingConversation: Conversation?
    @State private var renameText = ""
    @State private var renamingProject: AIChatProject?
    @State private var projectRenameText = ""
    @State private var deletingProject: AIChatProject?

    var body: some View {
        List(selection: $viewModel.selectedConversationID) {
            if showsProjects {
                Section(usesFolderTerminology ? "Klasörler" : "Projeler") {
                Button {
                    projectViewModel.selectedProjectID = nil
                } label: {
                    Label(
                        usesFolderTerminology
                            ? "Klasörsüz Sohbetler"
                            : "Projesiz Sohbetler",
                        systemImage:
                            projectViewModel.selectedProjectID == nil
                            ? "tray.full.fill"
                            : "tray.full"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    projectViewModel.selectedProjectID == nil
                        ? Color.accentColor.opacity(0.18)
                        : Color.clear
                )

                ForEach(projectViewModel.projects) { project in
                    Button {
                        projectViewModel.selectedProjectID = project.id
                    } label: {
                        Label(
                            project.name,
                            systemImage: projectViewModel.selectedProjectID
                                == project.id
                                ? "folder.fill"
                                : "folder"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "project-\(project.id.uuidString)"
                    )
                    .listRowBackground(
                        projectViewModel.selectedProjectID == project.id
                            ? Color.accentColor.opacity(0.18)
                            : Color.clear
                    )
                    .contextMenu {
                        Button("Yeniden Adlandır") {
                            projectRenameText = project.name
                            renamingProject = project
                        }
                        Divider()
                        Button(
                            usesFolderTerminology
                                ? "Klasörü Sil"
                                : "Projeyi Sil",
                            role: .destructive
                        ) {
                            deletingProject = project
                        }
                    }
                }

                Button(action: onCreateProject) {
                    Label(
                        usesFolderTerminology
                            ? "Yeni Klasör"
                            : "Yeni Proje",
                        systemImage: "folder.badge.plus"
                    )
                }
                .accessibilityIdentifier("new-project")
                }
            }

            Section(
                showsProjects && projectViewModel.selectedProject == nil
                    ? (
                        usesFolderTerminology
                            ? "Klasörsüz Sohbetler"
                            : "Projesiz Sohbetler"
                    )
                    : "Sohbetler"
            ) {
                ForEach(viewModel.conversations) { conversation in
                    row(for: conversation)
                        .tag(conversation.id)
                        .contextMenu {
                            Button("Yeniden Adlandır") {
                                renameText = conversation.title
                                renamingConversation = conversation
                            }
                            if showsProjects {
                                Menu(
                                    usesFolderTerminology
                                        ? "Klasöre Taşı"
                                        : "Projeye Taşı"
                                ) {
                                    Button(
                                        usesFolderTerminology
                                            ? "Klasörsüz Sohbetler"
                                            : "Projesiz Sohbetler"
                                    ) {
                                        Task {
                                            await viewModel.move(
                                                conversationID:
                                                    conversation.id,
                                                toProject: nil
                                            )
                                        }
                                    }
                                    .disabled(conversation.projectID == nil)

                                    Divider()

                                    ForEach(
                                        projectViewModel.projects
                                    ) { project in
                                        Button(project.name) {
                                            Task {
                                                await viewModel.move(
                                                    conversationID:
                                                        conversation.id,
                                                    toProject: project.id
                                                )
                                            }
                                        }
                                        .disabled(
                                            conversation.projectID
                                                == project.id
                                        )
                                    }
                                }
                            }
                            Divider()
                            Button("Sil", role: .destructive) {
                                Task {
                                    await viewModel.delete(
                                        conversationID: conversation.id
                                    )
                                }
                            }
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
        .animation(.default, value: viewModel.errorMessage)
        .onChange(of: viewModel.searchText) {
            Task { await viewModel.refresh() }
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
                .accessibilityIdentifier("sidebar-new-conversation")
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
        .alert(
            usesFolderTerminology
                ? "Klasörü Yeniden Adlandır"
                : "Projeyi Yeniden Adlandır",
            isPresented: Binding(
                get: { renamingProject != nil },
                set: { if !$0 { renamingProject = nil } }
            )
        ) {
            TextField(
                usesFolderTerminology ? "Klasör adı" : "Proje adı",
                text: $projectRenameText
            )
            Button("Vazgeç", role: .cancel) {}
            Button("Kaydet") {
                if let project = renamingProject {
                    Task {
                        await projectViewModel.rename(
                            projectID: project.id,
                            to: projectRenameText
                        )
                    }
                }
            }
        } message: {
            Text("Bu işlem disk üzerindeki klasörün adını değiştirmez.")
        }
        .confirmationDialog(
            "“\(deletingProject?.name ?? "")” \(usesFolderTerminology ? "klasörü" : "projesi") silinsin mi?",
            isPresented: Binding(
                get: { deletingProject != nil },
                set: { if !$0 { deletingProject = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(
                usesFolderTerminology ? "Klasörü Sil" : "Projeyi Sil",
                role: .destructive
            ) {
                if let project = deletingProject {
                    onDeleteProject(project)
                }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text(
                "Sohbetler silinmeyecek; \(usesFolderTerminology ? "Klasörsüz" : "Projesiz") Sohbetler bölümüne taşınacak."
            )
        }
        .safeAreaInset(edge: .bottom) {
            if let error = viewModel.errorMessage
                ?? projectViewModel.errorMessage {
                ErrorBannerView(message: error) {
                    viewModel.dismissError()
                    projectViewModel.dismissError()
                }
                .padding(8)
            }
        }
        .task {
            if showsProjects {
                await projectViewModel.refresh()
            }
            await viewModel.refresh()
        }
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
        .accessibilityIdentifier(
            "conversation-\(conversation.id.uuidString)"
        )
    }

}
