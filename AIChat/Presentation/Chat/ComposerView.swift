//
//  ComposerView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Presentation/Chat
//
//  Message input bar. Keyboard behavior (spec requirement):
//    Enter        → send
//    Shift+Enter  → newline
//  The send button morphs into a stop button while streaming, so the
//  cancellable operation is always visible (spec: "iptal edilebilir
//  işlemler görünür olmalı").
//

import SwiftUI

struct ComposerView: View {

    @Binding var draft: String
    let isStreaming: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Mesajınızı yazın…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...8)
                .padding(10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .focused($isFocused)
                .onKeyPress(.return, phases: .down) { press in
                    // Shift+Enter inserts a newline (let the field handle it),
                    // plain Enter sends.
                    if press.modifiers.contains(.shift) {
                        return .ignored
                    }
                    if canSend { onSend() }
                    return .handled
                }
                .disabled(isStreaming)

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
}

#Preview("Idle") {
    ComposerView(
        draft: .constant(""),
        isStreaming: false,
        canSend: false,
        onSend: {},
        onStop: {}
    )
    .frame(width: 560)
}

#Preview("Streaming") {
    ComposerView(
        draft: .constant(""),
        isStreaming: true,
        canSend: false,
        onSend: {},
        onStop: {}
    )
    .frame(width: 560)
}
