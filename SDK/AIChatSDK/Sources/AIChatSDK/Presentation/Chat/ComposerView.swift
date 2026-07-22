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
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool
    @Environment(\.aiChatTheme) private var theme
    @State private var editorHeight: CGFloat = 34
    @State private var isShowingFileImporter = false

    private let minEditorHeight: CGFloat = 34
    private let maxEditorHeight: CGFloat = 180

    public init(
        draft: Binding<String>,
        attachments: [ChatAttachment],
        isStreaming: Bool,
        canSend: Bool,
        onAddAttachment: @escaping (URL) -> Void,
        onRemoveAttachment: @escaping (UUID) -> Void,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        _draft = draft
        self.attachments = attachments
        self.isStreaming = isStreaming
        self.canSend = canSend
        self.onAddAttachment = onAddAttachment
        self.onRemoveAttachment = onRemoveAttachment
        self.onSend = onSend
        self.onStop = onStop
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !attachments.isEmpty {
                attachmentChips
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
    }

    // MARK: - Growing editor

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            // TextEditor has no placeholder of its own.
            if draft.isEmpty {
                Text("Mesajınızı yazın…")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $draft)
                .font(.body)
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
                    .font(.caption)
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
            .font(.body)
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
