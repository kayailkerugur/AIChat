import SwiftUI

/// Repository-aware chat experience used when the host selects code mode.
///
/// Repository information is read-only. The SDK does not stage, commit or
/// otherwise mutate the host repository.
public struct AIChatCodeView: View {
    @State private var codeViewModel: CodeModeViewModel
    @State private var chatViewModel: ChatViewModel
    @State private var fileSearchQuery = ""
    @Environment(\.aiChatTheme) private var environmentTheme
    @Environment(\.aiChatBranding) private var environmentBranding

    private let configuredTheme: AIChatTheme?
    private let configuredBranding: AIChatBranding?
    private let repositorySelectionAction: (() -> Void)?

    public init(
        codeViewModel: CodeModeViewModel,
        chatViewModel: ChatViewModel,
        theme: AIChatTheme? = nil,
        branding: AIChatBranding? = nil,
        onSelectRepository: (() -> Void)? = nil
    ) {
        _codeViewModel = State(initialValue: codeViewModel)
        _chatViewModel = State(initialValue: chatViewModel)
        configuredTheme = theme
        configuredBranding = branding
        repositorySelectionAction = onSelectRepository
    }

    public var body: some View {
        Group {
            if codeViewModel.repositoryStatus == nil {
                repositorySetupLayout
            } else {
                repositoryWorkspace
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.aiChatTheme, theme)
        .environment(\.aiChatBranding, branding)
        .task {
            guard codeViewModel.repositoryStatus == nil else { return }
            await codeViewModel.load()
        }
    }

    private var repositoryWorkspace: some View {
        HSplitView {
            repositorySidebar
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)

            VSplitView {
                diffPanel
                    .frame(minHeight: 160, idealHeight: 260)

                chatView
                    .frame(minHeight: 260)
            }
        }
    }

    private var repositorySetupLayout: some View {
        VStack(spacing: 0) {
            repositorySetupBanner
            Divider()
            chatView
        }
    }

    private var repositorySetupBanner: some View {
        HStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 28))
                .foregroundStyle(theme.accentColor)
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    codeViewModel.isLoadingRepository
                        ? "Repository yükleniyor…"
                        : "Bu sohbet için repository seçin"
                )
                .font(theme.titleFont)

                if !codeViewModel.isLoadingRepository {
                    Text(
                        codeViewModel.errorMessage
                            ?? "Kod değişikliklerini ve dosyaları bu sohbete bağlayın."
                    )
                    .font(theme.supportingFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }
            }

            Spacer(minLength: 16)

            if codeViewModel.isLoadingRepository {
                ProgressView()
                    .controlSize(.small)
            } else if codeViewModel.requiresRepositorySelection,
                      let repositorySelectionAction {
                Button("Repository Seç", action: repositorySelectionAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(
                        "code-mode-empty-select-repository"
                    )
            } else {
                Button("Yeniden Dene") {
                    Task { await codeViewModel.load() }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("code-mode-retry-repository")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.bar)
    }

    private var chatView: some View {
        AIChatView(
            viewModel: chatViewModel,
            theme: theme,
            branding: branding
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var repositorySidebar: some View {
        VStack(spacing: 0) {
            repositoryHeader
            Divider()

            if codeViewModel.isLoadingRepository,
               codeViewModel.repositoryStatus == nil {
                ProgressView("Repository yükleniyor…")
                    .font(theme.supportingFont)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let status = codeViewModel.repositoryStatus {
                repositoryList(status)
            } else {
                repositoryUnavailableView
            }
        }
        .background(.background)
    }

    private var repositoryUnavailableView: some View {
        ContentUnavailableView {
            Label(
                codeViewModel.requiresRepositorySelection
                    ? "Repository seçilmeli"
                    : "Repository kullanılamıyor",
                systemImage: "folder.badge.questionmark"
            )
        } description: {
            Text(
                codeViewModel.errorMessage
                    ?? "Repository bilgileri yüklenemedi."
            )
        } actions: {
            if codeViewModel.requiresRepositorySelection,
               let repositorySelectionAction {
                Button("Repository Seç", action: repositorySelectionAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(
                        "code-mode-empty-select-repository"
                    )
            } else {
                Button("Yeniden Dene") {
                    Task { await codeViewModel.load() }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("code-mode-retry-repository")
            }
        }
    }

    private var repositoryHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        codeViewModel.repositoryStatus?.repository.displayName
                            ?? "Repository"
                    )
                    .font(theme.titleFont)
                    .lineLimit(1)

                    if let status = codeViewModel.repositoryStatus {
                        Label(status.branchName, systemImage: "arrow.triangle.branch")
                            .font(theme.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    Task { await codeViewModel.refresh() }
                } label: {
                    if codeViewModel.isLoadingRepository {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(codeViewModel.isLoadingRepository)
                .help("Repository durumunu yenile")
            }

            if let errorMessage = codeViewModel.errorMessage {
                Text(errorMessage)
                    .font(theme.captionFont)
                    .foregroundStyle(theme.warningColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
    }

    private func repositoryList(_ status: RepositoryStatus) -> some View {
        VStack(spacing: 0) {
            if !codeViewModel.repositoryFiles.isEmpty {
                TextField("Dosyalarda ara", text: $fileSearchQuery)
                    .textFieldStyle(.roundedBorder)
                    .padding(8)
                Divider()
            }

            List {
                if status.changes.isEmpty {
                    Section("Değişiklikler") {
                        Label("Çalışma alanı temiz", systemImage: "checkmark.circle")
                            .font(theme.supportingFont)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(groupedChanges(status.changes), id: \.area) { group in
                        Section(group.title) {
                            ForEach(group.changes) { change in
                                Button {
                                    Task { await codeViewModel.select(change) }
                                } label: {
                                    changeRow(change)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(
                                    codeViewModel.selectedChange == change
                                        ? theme.accentColor.opacity(0.14)
                                        : Color.clear
                                )
                            }
                        }
                    }
                }

                if !codeViewModel.repositoryFiles.isEmpty {
                    Section("Repository dosyaları") {
                        ForEach(filteredRepositoryFiles.prefix(300)) { file in
                            Button {
                                Task { await codeViewModel.select(file) }
                            } label: {
                                Label(file.path, systemImage: "doc")
                                    .font(theme.supportingFont)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                codeViewModel.selectedFileContent?.file == file
                                    ? theme.accentColor.opacity(0.14)
                                    : Color.clear
                            )
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func changeRow(_ change: RepositoryChange) -> some View {
        HStack(spacing: 8) {
            Text(statusSymbol(for: change.status))
                .font(theme.codeFont)
                .foregroundStyle(statusColor(for: change.status))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(change.path)
                    .font(theme.supportingFont)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let originalPath = change.originalPath {
                    Text("önce: \(originalPath)")
                        .font(theme.captionFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
    }

    private var diffPanel: some View {
        VStack(spacing: 0) {
            HStack {
                if let change = codeViewModel.selectedChange {
                    Label(change.path, systemImage: "doc.text")
                        .font(theme.supportingFont)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if let file = codeViewModel.selectedFileContent?.file {
                    Label(file.path, systemImage: "doc")
                        .font(theme.supportingFont)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("Değişiklik önizlemesi")
                        .font(theme.supportingFont)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 36)

            Divider()

            if codeViewModel.isLoadingDiff || codeViewModel.isLoadingFile {
                ProgressView("Dosya yükleniyor…")
                    .font(theme.supportingFont)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let fileContent = codeViewModel.selectedFileContent {
                fileContentPreview(fileContent)
            } else if codeViewModel.selectedChange == nil {
                ContentUnavailableView(
                    "Bir değişiklik veya dosya seçin",
                    systemImage: "doc.text.magnifyingglass"
                )
            } else if codeViewModel.selectedDiff.isEmpty {
                ContentUnavailableView(
                    "Gösterilecek diff yok",
                    systemImage: "doc"
                )
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(codeViewModel.selectedDiff)
                        .font(theme.codeFont)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(12)
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }

    private func fileContentPreview(
        _ fileContent: RepositoryFileContent
    ) -> some View {
        VStack(spacing: 0) {
            if fileContent.containsRedactions || fileContent.wasTruncated {
                HStack(spacing: 12) {
                    if fileContent.containsRedactions {
                        Label(
                            "Hassas değerler maskelendi",
                            systemImage: "eye.slash"
                        )
                    }
                    if fileContent.wasTruncated {
                        Label("İçerik kesildi", systemImage: "scissors")
                    }
                    Spacer()
                }
                .font(theme.captionFont)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                Divider()
            }

            ScrollView([.horizontal, .vertical]) {
                Text(fileContent.content)
                    .font(theme.codeFont)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var theme: AIChatTheme {
        configuredTheme ?? environmentTheme
    }

    private var branding: AIChatBranding {
        configuredBranding ?? environmentBranding
    }

    private var filteredRepositoryFiles: [RepositoryFile] {
        let query = fileSearchQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else { return codeViewModel.repositoryFiles }
        return codeViewModel.repositoryFiles.filter {
            $0.path.localizedCaseInsensitiveContains(query)
        }
    }

    private func groupedChanges(
        _ changes: [RepositoryChange]
    ) -> [(area: RepositoryChangeArea, title: String, changes: [RepositoryChange])] {
        let order: [RepositoryChangeArea] = [
            .conflicted, .staged, .unstaged, .untracked
        ]
        return order.compactMap { area in
            let matches = changes.filter { $0.area == area }
            guard !matches.isEmpty else { return nil }
            return (area, areaTitle(area), matches)
        }
    }

    private func areaTitle(_ area: RepositoryChangeArea) -> String {
        switch area {
        case .staged: return "Staged"
        case .unstaged: return "Değişiklikler"
        case .untracked: return "İzlenmeyenler"
        case .conflicted: return "Çakışmalar"
        }
    }

    private func statusSymbol(for status: RepositoryChangeStatus) -> String {
        switch status {
        case .added: return "A"
        case .modified: return "M"
        case .deleted: return "D"
        case .renamed: return "R"
        case .copied: return "C"
        case .untracked: return "?"
        case .conflicted: return "!"
        }
    }

    private func statusColor(for status: RepositoryChangeStatus) -> Color {
        switch status {
        case .added, .copied: return .green
        case .modified, .renamed: return .orange
        case .deleted, .conflicted: return .red
        case .untracked: return .secondary
        }
    }
}
