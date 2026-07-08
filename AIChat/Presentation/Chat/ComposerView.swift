//
//  ComposerView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//

import SwiftUI

struct ComposerView: View {

    @Binding var draft: String
    let isStreaming: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool
    @State private var editorHeight: CGFloat = 34

    private let minEditorHeight: CGFloat = 34
    private let maxEditorHeight: CGFloat = 180

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            editor

            Button {
                isStreaming ? onStop() : onSend()
            } label: {
                Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(isStreaming || canSend ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.plain)
            .disabled(!isStreaming && !canSend)
            .keyboardShortcut(isStreaming ? .cancelAction : .defaultAction)
            .accessibilityLabel(isStreaming ? "Yanıtı durdur" : "Mesajı gönder")
            .padding(.bottom, 4)
        }
        .padding(12)
        .onAppear { isFocused = true }
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
        isStreaming: false,
        canSend: false,
        onSend: {},
        onStop: {}
    )
    .frame(width: 560)
}

#Preview("Few lines (grows)") {
    ComposerView(
        draft: .constant("Birinci satır\nİkinci satır\nÜçüncü satır"),
        isStreaming: false,
        canSend: true,
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
        isStreaming: false,
        canSend: true,
        onSend: {},
        onStop: {}
    )
    .frame(width: 560)
}
