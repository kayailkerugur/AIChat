import AIChatSDK
import SwiftUI

struct ProjectDetailView: View {
    let project: AIChatProject
    @State private var repositoryViewModel: CodeModeViewModel
    @State private var workspaceViewModel: ProjectWorkspaceViewModel
    @State private var contextFilesViewModel: ProjectContextFilesViewModel?
    let onSelectRepository: () -> Void
    let onCreateConversation: () -> Void
    let onOpenConversation: (UUID) -> Void

    init(
        project: AIChatProject,
        repositoryViewModel: CodeModeViewModel,
        conversationRepository: any ConversationRepository,
        contextFilesViewModel: ProjectContextFilesViewModel?,
        onSelectRepository: @escaping () -> Void,
        onCreateConversation: @escaping () -> Void,
        onOpenConversation: @escaping (UUID) -> Void
    ) {
        self.project = project
        _repositoryViewModel = State(initialValue: repositoryViewModel)
        _workspaceViewModel = State(initialValue: ProjectWorkspaceViewModel(
            projectID: project.id,
            conversationRepository: conversationRepository
        ))
        _contextFilesViewModel = State(initialValue: contextFilesViewModel)
        self.onSelectRepository = onSelectRepository
        self.onCreateConversation = onCreateConversation
        self.onOpenConversation = onOpenConversation
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                repositoryCard
                projectContextCard
                activityCard
                if let status = repositoryViewModel.repositoryStatus {
                    repositoryBrowser(status)
                }
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            async let repositoryLoad: Void = repositoryViewModel.load()
            async let activityLoad: Void = workspaceViewModel.load()
            _ = await (repositoryLoad, activityLoad)
            await contextFilesViewModel?.load()
        }
        .onChange(of: repositoryViewModel.repositoryFiles.map(\.path)) {
            Task {
                await contextFilesViewModel?.load()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "folder.fill")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.largeTitle.bold())
                Text(repositoryPath)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
                HStack(spacing: 6) {
                    ForEach(technologies, id: \.self) { technology in
                        Text(technology)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
            Spacer()
            Button(action: onCreateConversation) {
                Label("Yeni Sohbet", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("project-new-conversation")
        }
    }

    private var repositoryPath: String {
        repositoryViewModel.repositoryStatus?.repository.rootURL.path
            ?? "Repository seçildiğinde proje yolu burada görünür."
    }

    private var technologies: [String] {
        workspaceViewModel.technologies(
            from: repositoryViewModel.repositoryFiles
        )
    }

    private var repositoryCard: some View {
        GroupBox("Repository") {
            HStack(spacing: 16) {
                Image(
                    systemName: repositoryViewModel.repositoryStatus == nil
                        ? "externaldrive.badge.questionmark"
                        : "externaldrive.fill"
                )
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    if let status = repositoryViewModel.repositoryStatus {
                        Text(status.repository.displayName)
                            .font(.headline)
                        Text("Branch: \(status.branchName)")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("project-repository-branch")
                        if let remoteURL = status.remoteURL {
                            Text(remoteURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .textSelection(.enabled)
                        }
                        HStack(spacing: 12) {
                            if let summary = status.lastCommitSummary {
                                Label(summary, systemImage: "clock.arrow.circlepath")
                                    .lineLimit(1)
                            }
                            Label(
                                status.changes.isEmpty
                                    ? "Temiz"
                                    : "\(status.changes.count) değişiklik",
                                systemImage: status.changes.isEmpty
                                    ? "checkmark.circle"
                                    : "pencil.circle"
                            )
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else if repositoryViewModel.isLoadingRepository {
                        Text("Repository yükleniyor…")
                    } else {
                        Text("Repository seçilmedi")
                            .font(.headline)
                        Text(
                            repositoryViewModel.errorMessage
                                ?? "Bu projeye bir Git klasörü bağlayın."
                        )
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            "project-repository-error"
                        )
                    }
                }

                Spacer()

                if repositoryViewModel.isLoadingRepository {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button(
                        repositoryViewModel.repositoryStatus == nil
                            ? "Repository Seç"
                            : "Değiştir",
                        action: onSelectRepository
                    )
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("project-select-repository")

                    if repositoryViewModel.repositoryStatus != nil {
                        Button {
                            Task { await repositoryViewModel.refresh() }
                        } label: {
                            Label("Yenile", systemImage: "arrow.clockwise")
                        }
                        .accessibilityIdentifier("project-refresh-repository")
                    }
                }
            }
            .padding(8)
        }
    }

    private var projectContextCard: some View {
        GroupBox("Proje Bağlamı") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Açıklama")
                        .font(.headline)
                    TextField(
                        "Bu projenin amacı ve kapsamı",
                        text: $workspaceViewModel.summary,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Spacer()
                    Button("Açıklamayı Kaydet") {
                        workspaceViewModel.saveContext()
                    }
                    .accessibilityIdentifier("save-project-summary")
                }

                Divider()

                contextFilesEditor
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var contextFilesEditor: some View {
        if let editor = contextFilesViewModel {
            @Bindable var editor = editor
            VStack(alignment: .leading, spacing: 10) {
                Text("Bağlam Dosyaları")
                    .font(.headline)

                if editor.isLoading && editor.files.isEmpty {
                    ProgressView("Bağlam dosyaları yükleniyor…")
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if editor.files.isEmpty {
                    ContentUnavailableView(
                        "Bağlam dosyası bulunamadı",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(
                            editor.errorMessage
                                ?? "README.md, AGENTS.md veya desteklenen başka bir bağlam dosyası bulunamadı."
                        )
                    )
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    HSplitView {
                        List(editor.files, selection: Binding(
                            get: { editor.selectedFile?.id },
                            set: { selectedID in
                                guard let file = editor.files.first(
                                    where: { $0.id == selectedID }
                                ) else { return }
                                Task { await editor.select(file) }
                            }
                        )) { file in
                            Label(file.path, systemImage: "doc.text")
                                .lineLimit(1)
                                .tag(file.id)
                        }
                        .frame(minWidth: 190, idealWidth: 230)
                        .accessibilityIdentifier("context-files-list")

                        VStack(alignment: .leading, spacing: 8) {
                            Text(editor.selectedFile?.path ?? "Dosya seçin")
                                .font(.headline)
                                .lineLimit(1)

                            TextEditor(text: $editor.content)
                                .font(.system(.body, design: .monospaced))
                                .disabled(editor.selectedFile == nil)
                                .accessibilityIdentifier("context-file-editor")

                            HStack {
                                if editor.isSaving {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Button("Kaydet") {
                                    Task { await editor.save() }
                                }
                                .disabled(!editor.canSave)
                                .accessibilityIdentifier("save-context-file")

                                Button("Değişiklikleri Geri Al") {
                                    editor.revert()
                                }
                                .disabled(!editor.hasChanges)

                                Spacer()
                                if editor.hasChanges {
                                    Text("Kaydedilmemiş değişiklikler")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .frame(minWidth: 320)
                    }
                    .frame(height: 300)
                }

                if let infoMessage = editor.infoMessage {
                    Label(infoMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
                if let errorMessage = editor.errorMessage,
                   !editor.files.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        } else {
            ContentUnavailableView(
                "Bağlam dosyaları kullanılamıyor",
                systemImage: "doc.text.magnifyingglass",
                description: Text(
                    "Repository sağlayıcısı yapılandırıldığında bağlam dosyaları burada açılabilir."
                )
            )
            .frame(maxWidth: .infinity, minHeight: 150)
        }
    }

    private var activityCard: some View {
        GroupBox("Aktivite") {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    "\(workspaceViewModel.conversations.count) sohbet",
                    systemImage: "bubble.left.and.bubble.right"
                )
                .font(.headline)

                if workspaceViewModel.conversations.isEmpty {
                    Text("Bu projede henüz sohbet yok.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workspaceViewModel.conversations.prefix(5)) {
                        conversation in
                        Button {
                            onOpenConversation(conversation.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(conversation.title)
                                        .lineLimit(1)
                                    Text(
                                        conversation.updatedAt,
                                        format: .relative(presentation: .named)
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func repositoryBrowser(_ status: RepositoryStatus) -> some View {
        GroupBox("Repository İçeriği") {
            HSplitView {
                List {
                    Section("Değişiklikler") {
                        if status.changes.isEmpty {
                            Label(
                                "Çalışma ağacı temiz",
                                systemImage: "checkmark.circle"
                            )
                            .foregroundStyle(.secondary)
                        } else {
                            ForEach(status.changes) { change in
                                Button {
                                    Task {
                                        await repositoryViewModel.select(
                                            change
                                        )
                                    }
                                } label: {
                                    Label(
                                        change.path,
                                        systemImage: icon(
                                            for: change.status
                                        )
                                    )
                                    .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(
                                    "repository-change-\(change.path)"
                                )
                            }
                        }
                    }

                    if !repositoryViewModel.repositoryFiles.isEmpty {
                        Section("Dosyalar") {
                            ForEach(
                                repositoryViewModel.repositoryFiles
                            ) { file in
                                Button {
                                    Task {
                                        await repositoryViewModel.select(file)
                                    }
                                } label: {
                                    Label(
                                        file.path,
                                        systemImage: "doc.text"
                                    )
                                    .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(
                                    "repository-file-\(file.path)"
                                )
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .frame(
                    minWidth: 220,
                    idealWidth: 280,
                    maxHeight: .infinity,
                    alignment: .top
                )

                repositoryPreview
                    .frame(
                        minWidth: 320,
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
            .frame(height: 380)
        }
    }

    @ViewBuilder
    private var repositoryPreview: some View {
        if repositoryViewModel.isLoadingDiff
            || repositoryViewModel.isLoadingFile {
            ProgressView("İçerik yükleniyor…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let fileContent =
                    repositoryViewModel.selectedFileContent {
            codePreview(
                title: fileContent.file.path,
                content: fileContent.content
            )
        } else if let change = repositoryViewModel.selectedChange {
            codePreview(
                title: change.path,
                content: repositoryViewModel.selectedDiff
            )
        } else {
            ContentUnavailableView(
                "Bir değişiklik veya dosya seçin",
                systemImage: "doc.text.magnifyingglass"
            )
        }
    }

    private func codePreview(
        title: String,
        content: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .padding(12)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                Text(content.isEmpty ? "İçerik bulunamadı." : content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .accessibilityIdentifier("repository-preview-content")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
    }

    private func icon(for status: RepositoryChangeStatus) -> String {
        switch status {
        case .added:
            "plus.circle"
        case .modified:
            "pencil.circle"
        case .deleted:
            "minus.circle"
        case .renamed:
            "arrow.right.circle"
        case .copied:
            "doc.on.doc"
        case .untracked:
            "questionmark.circle"
        case .conflicted:
            "exclamationmark.triangle"
        }
    }
}
