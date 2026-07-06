//
//  MessageBubbleView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//

import SwiftUI

struct MessageBubbleView: View {

    let message: ChatMessage
    var onRetry: (() -> Void)? = nil

    @State private var isHovering = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                bubble

                statusFooter
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Kopyala") { copyToPasteboard(message.content) }
                .disabled(message.content.isEmpty)
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var bubble: some View {
        Group {
            if message.status == .streaming && message.content.isEmpty {
                // Waiting for the first delta.
                TypingIndicatorView()
            } else if isUser {
                // User input is shown verbatim — rendering the user's own
                // markdown would silently alter what they typed.
                Text(message.content)
                    .textSelection(.enabled)
            } else {
                // Assistant responses get markdown + code block rendering.
                MessageContentView(content: message.content)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isUser ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.quaternary.opacity(0.5)),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(alignment: .topTrailing) {
            // Hover copy button (macOS nicety) — context menu also works.
            if isHovering && !message.content.isEmpty {
                Button {
                    copyToPasteboard(message.content)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .padding(4)
                .accessibilityLabel("Mesajı kopyala")
            }
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        switch message.status {
        case .cancelled:
            Text("Yanıt durduruldu")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .failed:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message.errorDescription ?? "Bir hata oluştu.")
                    .font(.caption)
                if let onRetry {
                    Button("Tekrar dene", action: onRetry)
                        .font(.caption)
                        .buttonStyle(.link)
                }
            }

        case .sending, .streaming, .completed:
            EmptyView()
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// Three pulsing dots shown before the first delta arrives.
struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundStyle(.secondary)
                    .opacity(animating ? 0.3 : 1)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.vertical, 4)
        .onAppear { animating = true }
        .accessibilityLabel("Yanıt bekleniyor")
    }
}

#Preview("States") {
    VStack(spacing: 12) {
        MessageBubbleView(message: ChatMessage(role: .user, content: "Merhaba, bana Swift anlatır mısın?"))
        MessageBubbleView(message: ChatMessage(role: .assistant, content: "Tabii! Swift, Apple platformları için geliştirilen modern bir dildir."))
        MessageBubbleView(message: ChatMessage(role: .assistant, content: "", status: .streaming))
        MessageBubbleView(message: ChatMessage(role: .assistant, content: "Yanıtın yarısı geldi ve", status: .cancelled))
        MessageBubbleView(
            message: ChatMessage(role: .assistant, content: "", status: .failed,
                                 errorDescription: "Bağlantı kurulamadı."),
            onRetry: {}
        )
    }
    .padding()
    .frame(width: 560)
}
