//
//  MessageBubbleView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//

import SwiftUI
import PDFKit
import AppKit

public struct MessageBubbleView: View {

    let message: ChatMessage
    var onRetry: (() -> Void)? = nil
    var onDeleteAttachment: ((UUID, UUID) -> Void)? = nil

    @State private var isHovering = false
    @State private var previewAttachment: ChatAttachment?
    @Environment(\.aiChatTheme) private var theme

    private var isUser: Bool { message.role == .user }

    public init(
        message: ChatMessage,
        onRetry: (() -> Void)? = nil,
        onDeleteAttachment: ((UUID, UUID) -> Void)? = nil
    ) {
        self.message = message
        self.onRetry = onRetry
        self.onDeleteAttachment = onDeleteAttachment
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                bubble
                attachmentChips

                statusFooter
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Kopyala") { copyToPasteboard(message.content) }
                .disabled(message.content.isEmpty)
        }
        .sheet(item: $previewAttachment) { attachment in
            AttachmentPreviewSheet(attachment: attachment)
        }
    }

    @ViewBuilder
    private var attachmentChips: some View {
        if !message.attachments.isEmpty {
            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                ForEach(message.attachments) { attachment in
                    AttachmentPreviewTrigger(attachment: attachment) {
                        previewAttachment = attachment
                    } onDelete: {
                        onDeleteAttachment?(message.id, attachment.id)
                    }
                }
            }
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
        .font(theme.bodyFont)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isUser
                ? AnyShapeStyle(theme.accentColor.opacity(0.18))
                : AnyShapeStyle(.quaternary.opacity(0.5)),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(alignment: .topTrailing) {
            // Hover copy button (macOS nicety) — context menu also works.
            if isHovering && !message.content.isEmpty {
                Button {
                    copyToPasteboard(message.content)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(theme.captionFont)
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
                .font(theme.captionFont)
                .foregroundStyle(.secondary)

        case .failed:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.warningColor)
                Text(message.errorDescription ?? "Bir hata oluştu.")
                    .font(theme.captionFont)
                if let onRetry {
                    Button("Tekrar dene", action: onRetry)
                        .font(theme.captionFont)
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

private struct AttachmentPreviewTrigger: View {

    let attachment: ChatAttachment
    let onOpen: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        Button(action: onOpen) {
            switch attachment.kind {
            case .image:
                imageThumbnail
            case .document:
                documentRow
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Önizle", action: onOpen)
            Button("Kopyala") {
                copyAttachment()
            }
            Button("Dışa Aktar...") {
                exportAttachment()
            }
            Button("Finder'da Göster") {
                revealInFinder()
            }
            if let onDelete {
                Divider()
                Button("Eki Sil", role: .destructive, action: onDelete)
            }
        }
        .accessibilityLabel("\(attachment.fileName) önizle")
    }

    private var imageThumbnail: some View {
        Group {
            if let image = NSImage(data: attachment.data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary.opacity(0.45))
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
        .overlay(alignment: .bottomLeading) {
            Text(attachment.fileName)
                .font(.caption2)
                .lineLimit(1)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
        }
        .frame(width: 84, height: 84)
    }

    private var documentRow: some View {
        HStack(spacing: 10) {
            Image(systemName: attachment.isPDF ? "doc.richtext" : "doc.text")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.callout)
                    .lineLimit(1)
                Text(attachment.isPDF ? "PDF" : attachment.mimeType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Image(systemName: "eye")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 280)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private func copyAttachment() {
        NSPasteboard.general.clearContents()

        if attachment.kind == .image, let image = NSImage(data: attachment.data) {
            NSPasteboard.general.writeObjects([image])
            return
        }

        do {
            let url = try temporaryFileURL()
            NSPasteboard.general.writeObjects([url as NSURL])
        } catch {
            NSSound.beep()
        }
    }

    private func exportAttachment() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = attachment.fileName
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try attachment.data.write(to: url, options: .atomic)
            } catch {
                NSSound.beep()
            }
        }
    }

    private func revealInFinder() {
        do {
            let url = try temporaryFileURL()
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSSound.beep()
        }
    }

    private func temporaryFileURL() throws -> URL {
        let directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("AIChatAttachments", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let url = directory.appendingPathComponent(attachment.safeFileName)
        try attachment.data.write(to: url, options: .atomic)
        return url
    }
}

private struct AttachmentPreviewSheet: View {

    let attachment: ChatAttachment
    @Environment(\.dismiss) private var dismiss

    private var windowSize: CGSize {
        if attachment.kind == .image, let image = NSImage(data: attachment.data) {
            return Self.previewWindowSize(for: image.size)
        }

        if attachment.isPDF,
           let document = PDFDocument(data: attachment.data),
           let page = document.page(at: 0) {
            return Self.previewWindowSize(for: page.bounds(for: .mediaBox).size)
        }

        return Self.previewWindowSize(for: CGSize(width: 900, height: 620))
    }

    private var contentSize: CGSize {
        CGSize(width: windowSize.width, height: max(windowSize.height - 58, 360))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(attachment.fileName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button("Kapat") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            previewContent
                .frame(width: contentSize.width, height: contentSize.height)
        }
        .frame(width: windowSize.width, height: windowSize.height)
    }

    @ViewBuilder
    private var previewContent: some View {
        if attachment.kind == .image, let image = NSImage(data: attachment.data) {
            ZStack {
                Color.clear
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .frame(width: contentSize.width, height: contentSize.height)
            }
        } else if attachment.isPDF, let document = PDFDocument(data: attachment.data) {
            PDFPreview(document: document)
        } else if let text = attachment.extractedText, !text.isEmpty {
            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        } else {
            ContentUnavailableView(
                "Önizleme yok",
                systemImage: "doc.questionmark",
                description: Text("Bu dosya türü için uygulama içi önizleme desteklenmiyor.")
            )
        }
    }

    private static func previewWindowSize(for contentSize: CGSize) -> CGSize {
        let screenSize = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        let maxWidth = min(screenSize.width * 0.86, 1180)
        let maxHeight = min(screenSize.height * 0.86, 920)
        let minWidth: CGFloat = 560
        let minHeight: CGFloat = 420
        let headerHeight: CGFloat = 58
        let horizontalPadding: CGFloat = 32
        let verticalPadding: CGFloat = 32

        let safeContentSize = CGSize(
            width: max(contentSize.width, 1),
            height: max(contentSize.height, 1)
        )
        let availableWidth = maxWidth - horizontalPadding
        let availableHeight = maxHeight - headerHeight - verticalPadding
        let scale = min(availableWidth / safeContentSize.width, availableHeight / safeContentSize.height)
        let previewWidth = safeContentSize.width * scale + horizontalPadding
        let previewHeight = safeContentSize.height * scale + headerHeight + verticalPadding

        return CGSize(
            width: min(max(previewWidth, minWidth), maxWidth),
            height: min(max(previewHeight, minHeight), maxHeight)
        )
    }
}

private struct PDFPreview: NSViewRepresentable {

    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = document
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        view.document = document
    }
}

private extension ChatAttachment {
    var isPDF: Bool {
        mimeType == "application/pdf" || fileName.lowercased().hasSuffix(".pdf")
    }

    var safeFileName: String {
        let invalidCharacters = CharacterSet(charactersIn: "/:")
            .union(.newlines)
            .union(.controlCharacters)
        let components = fileName.components(separatedBy: invalidCharacters)
        let sanitized = components
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "attachment" : sanitized
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
