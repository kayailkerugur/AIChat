//
//  ComposerView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//

import SwiftUI
import UniformTypeIdentifiers

public struct ComposerView: View {

    @Binding var draft: String
    let attachments: [ChatAttachment]
    let isStreaming: Bool
    let canSend: Bool
    let onAddAttachment: (URL) -> Void
    let onRemoveAttachment: (UUID) -> Void
    let repositoryFiles: [RepositoryFile]
    let selectedRepositoryFile: RepositoryFile?
    let onSelectRepositoryFile: ((RepositoryFile) -> Void)?
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool
    @FocusState private var isRepositorySearchFocused: Bool
    @Environment(\.aiChatTheme) private var theme
    @State private var editorHeight: CGFloat = 34
    @State private var isShowingFileImporter = false
    @State private var isShowingRepositoryFiles = false
    @State private var repositoryFileQuery = ""

    private let minEditorHeight: CGFloat = 34
    private let maxEditorHeight: CGFloat = 180

    public init(
        draft: Binding<String>,
        attachments: [ChatAttachment],
        isStreaming: Bool,
        canSend: Bool,
        onAddAttachment: @escaping (URL) -> Void,
        onRemoveAttachment: @escaping (UUID) -> Void,
        repositoryFiles: [RepositoryFile] = [],
        selectedRepositoryFile: RepositoryFile? = nil,
        onSelectRepositoryFile: ((RepositoryFile) -> Void)? = nil,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        _draft = draft
        self.attachments = attachments
        self.isStreaming = isStreaming
        self.canSend = canSend
        self.onAddAttachment = onAddAttachment
        self.onRemoveAttachment = onRemoveAttachment
        self.repositoryFiles = repositoryFiles
        self.selectedRepositoryFile = selectedRepositoryFile
        self.onSelectRepositoryFile = onSelectRepositoryFile
        self.onSend = onSend
        self.onStop = onStop
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !attachments.isEmpty {
                attachmentChips
            }
            if let selectedRepositoryFile {
                Label(selectedRepositoryFile.path, systemImage: "doc.text")
                    .font(theme.captionFont)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.quaternary.opacity(0.6), in: Capsule())
                    .accessibilityIdentifier("selected-repository-file")
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    isShowingFileImporter = true
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18))
                }
                .buttonStyle(.borderless)
                .disabled(isStreaming)
                .accessibilityLabel("Dosya ekle")
                .padding(.bottom, 8)

                editor

                Button {
                    isStreaming ? onStop() : onSend()
                } label: {
                    Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            isStreaming || canSend
                                ? AnyShapeStyle(theme.accentColor)
                                : AnyShapeStyle(.tertiary)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isStreaming && !canSend)
                .keyboardShortcut(isStreaming ? .cancelAction : .defaultAction)
                .accessibilityLabel(isStreaming ? "Yanıtı durdur" : "Mesajı gönder")
                .padding(.bottom, 4)
            }
        }
        .padding(12)
        .onAppear { isFocused = true }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: AttachmentLoader.allowedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                urls.forEach(onAddAttachment)
            case .failure:
                break
            }
        }
        .onChange(of: draft) {
            updateRepositoryFilePicker()
        }
        .sheet(isPresented: $isShowingRepositoryFiles) {
            repositoryFilePicker
        }
    }

    // MARK: - Growing editor

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            // TextEditor has no placeholder of its own.
            if draft.isEmpty {
                Text("Mesajınızı yazın…")
                    .font(theme.bodyFont)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $draft)
                .font(theme.bodyFont)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .frame(height: editorHeight)
                .focused($isFocused)
                .onKeyPress(.return, phases: .down) { press in
                    // Shift+Enter inserts a newline (let the editor handle
                    // it), plain Enter sends.
                    if press.modifiers.contains(.shift) {
                        return .ignored
                    }
                    if canSend { onSend() }
                    return .handled
                }
                .disabled(isStreaming)
                .accessibilityLabel("Mesaj alanı")
        }
        .background(heightMeasurer)
        .onPreferenceChange(EditorHeightPreferenceKey.self) { measured in
            editorHeight = min(max(measured, minEditorHeight), maxEditorHeight)
        }
        .animation(.easeOut(duration: 0.1), value: editorHeight)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private var matchingRepositoryFiles: [RepositoryFile] {
        guard !repositoryFileQuery.isEmpty else {
            return repositoryFiles
        }
        return repositoryFiles
            .filter {
                $0.path.localizedCaseInsensitiveContains(
                    repositoryFileQuery
                )
            }
            .sorted { lhs, rhs in
                let lhsName = URL(fileURLWithPath: lhs.path)
                    .lastPathComponent
                let rhsName = URL(fileURLWithPath: rhs.path)
                    .lastPathComponent
                let lhsStarts = lhsName.localizedCaseInsensitiveContains(
                    repositoryFileQuery
                )
                let rhsStarts = rhsName.localizedCaseInsensitiveContains(
                    repositoryFileQuery
                )
                if lhsStarts != rhsStarts {
                    return lhsStarts
                }
                return lhs.path.localizedStandardCompare(rhs.path)
                    == .orderedAscending
            }
    }

    private var repositoryFilePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Repository Dosyası Seç")
                        .font(.title2.bold())
                    Text("\(matchingRepositoryFiles.count) dosya")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Vazgeç") {
                    isShowingRepositoryFiles = false
                }
                .keyboardShortcut(.cancelAction)
            }

            TextField(
                "Dosya adı veya klasör yolu ara",
                text: $repositoryFileQuery
            )
            .textFieldStyle(.roundedBorder)
            .focused($isRepositorySearchFocused)
            .accessibilityIdentifier("repository-file-search")

            if matchingRepositoryFiles.isEmpty {
                ContentUnavailableView(
                    "Dosya bulunamadı",
                    systemImage: "doc.text.magnifyingglass"
                )
            } else {
                List(matchingRepositoryFiles) { file in
                    Button {
                        selectRepositoryFile(file)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(
                                    URL(fileURLWithPath: file.path)
                                        .lastPathComponent
                                )
                                .font(.body)
                                Text(file.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "repository-mention-\(file.path)"
                    )
                }
            }
        }
        .padding(20)
        .frame(minWidth: 620, idealWidth: 720, minHeight: 460)
        .onAppear {
            isRepositorySearchFocused = true
        }
        .accessibilityIdentifier("repository-file-picker")
    }

    private func updateRepositoryFilePicker() {
        guard onSelectRepositoryFile != nil,
              !repositoryFiles.isEmpty,
              let token = repositoryMentionToken else {
            isShowingRepositoryFiles = false
            repositoryFileQuery = ""
            return
        }
        repositoryFileQuery = String(token.dropFirst())
        isShowingRepositoryFiles = true
    }

    private var repositoryMentionToken: Substring? {
        guard let atIndex = draft.lastIndex(of: "@") else { return nil }
        if atIndex > draft.startIndex {
            let previous = draft.index(before: atIndex)
            guard draft[previous].isWhitespace else { return nil }
        }
        let token = draft[atIndex...]
        guard !token.dropFirst().contains(where: \.isWhitespace) else {
            return nil
        }
        return token
    }

    private func selectRepositoryFile(_ file: RepositoryFile) {
        if let token = repositoryMentionToken,
           let range = draft.range(of: token, options: .backwards) {
            draft.replaceSubrange(range, with: "@\(file.path) ")
        }
        isShowingRepositoryFiles = false
        repositoryFileQuery = ""
        onSelectRepositoryFile?(file)
        isFocused = true
    }

    private var attachmentChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    HStack(spacing: 6) {
                        Image(systemName: attachment.kind == .image ? "photo" : "doc.text")
                        Text(attachment.fileName)
                            .lineLimit(1)
                        Button {
                            onRemoveAttachment(attachment.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Eki kaldır")
                    }
                    .font(theme.captionFont)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.quaternary.opacity(0.6), in: Capsule())
                }
            }
        }
    }

    /// Hidden mirror of the draft. Lives in .background so it takes no
    /// part in layout; fixedSize lets it report the text's NATURAL
    /// height (even beyond the editor's clamped frame), which flows up
    /// through the preference key.
    private var heightMeasurer: some View {
        Text(draft.isEmpty ? " " : draft)
            .font(theme.bodyFont)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: EditorHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            )
            .hidden()
    }
}

private struct EditorHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview("Idle (single line)") {
    ComposerView(
        draft: .constant(""),
        attachments: [],
        isStreaming: false,
        canSend: false,
        onAddAttachment: { _ in },
        onRemoveAttachment: { _ in },
        onSend: {},
        onStop: {}
    )
    .frame(width: 560)
}

#Preview("Few lines (grows)") {
    ComposerView(
        draft: .constant("Birinci satır\nİkinci satır\nÜçüncü satır"),
        attachments: [],
        isStreaming: false,
        canSend: true,
        onAddAttachment: { _ in },
        onRemoveAttachment: { _ in },
        onSend: {},
        onStop: {}
    )
    .frame(width: 560)
}

#Preview("Large pasted text (caps + scrolls)") {
    ComposerView(
        draft: .constant(
            (1...40).map { "Yapıştırılan uzun metnin \($0). satırı" }
                .joined(separator: "\n")
        ),
        attachments: [],
        isStreaming: false,
        canSend: true,
        onAddAttachment: { _ in },
        onRemoveAttachment: { _ in },
        onSend: {},
        onStop: {}
    )
    .frame(width: 560)
}
