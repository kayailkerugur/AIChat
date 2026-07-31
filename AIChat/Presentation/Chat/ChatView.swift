import AIChatSDK
import SwiftUI

/// Main App wrapper that owns the application-specific Voice sheet.
struct ChatView: View {
    let viewModel: ChatViewModel
    let codeModeViewModel: CodeModeViewModel?
    let projectName: String?

    @State private var isShowingVoiceCall = false

    init(
        viewModel: ChatViewModel,
        codeModeViewModel: CodeModeViewModel? = nil,
        projectName: String? = nil
    ) {
        self.viewModel = viewModel
        self.codeModeViewModel = codeModeViewModel
        self.projectName = projectName
    }

    let theme = AIChatTheme(
        accentColor: .purple,
        titleFont: .largeTitle,
        bodyFont: .custom("Avenir Next", size: 15),
        supportingFont: .custom("Avenir Next", size: 13),
        captionFont: .caption,
        codeFont: .system(.callout, design: .monospaced)
    )

    let branding = AIChatBranding(
        logo: Image("CompanyLogo"),
        emptyStateImage: Image(systemName: "sparkles")
    )

    var body: some View {
        VStack(spacing: 0) {
            if let codeModeViewModel {
                repositoryContextBar(codeModeViewModel)
                Divider()
                editProposalView(codeModeViewModel)
            }

            AIChatView(
                viewModel: viewModel,
                theme: theme,
                branding: branding,
                repositoryFiles: codeModeViewModel?.repositoryFiles ?? [],
                selectedRepositoryFile:
                    codeModeViewModel?.selectedFileContent?.file,
                onSelectRepositoryFile: codeModeViewModel.map { codeViewModel in
                    { file in
                        Task { await codeViewModel.select(file) }
                    }
                }
            )
        }
        .onChange(of: viewModel.messages.last) { _, message in
            guard message?.role == .assistant,
                  message?.status == .completed,
                  let content = message?.content else { return }
            codeModeViewModel?.prepareEditProposal(from: content)
        }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        isShowingVoiceCall = true
                    } label: {
                        Label("Sesli Görüşme", systemImage: "phone.fill")
                    }
                }
            }
            .sheet(isPresented: $isShowingVoiceCall) {
                VoiceCallView(
                    viewModel: VoiceCallViewModel(chatViewModel: viewModel)
                )
            }
    }

    @ViewBuilder
    private func editProposalView(
        _ codeModeViewModel: CodeModeViewModel
    ) -> some View {
        if let proposal = codeModeViewModel.editProposal {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(
                        "\(proposal.file.path) için değişiklik önerisi",
                        systemImage: "doc.badge.gearshape"
                    )
                    .font(.headline)
                    Spacer()
                    Button("Vazgeç") {
                        codeModeViewModel.dismissEditProposal()
                    }
                    Button("Uygula") {
                        Task {
                            await codeModeViewModel.applyEditProposal()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("apply-code-edit")
                }

                ScrollView([.horizontal, .vertical]) {
                    Text(proposal.preview)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
                .accessibilityIdentifier("code-edit-preview")
            }
            .padding(12)
            .background(.quaternary.opacity(0.35))
        } else if let message = codeModeViewModel.editInfoMessage {
            Label(message, systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func repositoryContextBar(
        _ codeModeViewModel: CodeModeViewModel
    ) -> some View {
        if let status = codeModeViewModel.repositoryStatus {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(projectName ?? status.repository.displayName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(status.repository.rootURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(status.repository.rootURL.path)
                }

                Spacer(minLength: 12)

                Label(status.repository.displayName, systemImage: "externaldrive")
                    .lineLimit(1)
                Text(status.branchName)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
                    .accessibilityIdentifier("chat-repository-branch")
            }
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("chat-repository-context")
        } else if codeModeViewModel.isLoadingRepository {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Repository bilgisi yükleniyor…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        } else if let errorMessage = codeModeViewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }
}
