//
//  CodeBlockView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//

import SwiftUI

public struct CodeBlockView: View {

    let language: String?
    let code: String

    @State private var didCopy = false
    @Environment(\.aiChatTheme) private var theme

    public init(language: String?, code: String) {
        self.language = language
        self.code = code
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(theme.codeFont)
                    .textSelection(.enabled)
                    .padding(10)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Text(language ?? "kod")
                .font(theme.captionFont)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
                didCopy = true
                // Brief visual confirmation, then revert.
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    didCopy = false
                }
            } label: {
                Label(
                    didCopy ? "Kopyalandı" : "Kopyala",
                    systemImage: didCopy ? "checkmark" : "doc.on.doc"
                )
                .font(theme.captionFont)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Kod bloğunu kopyala")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

#Preview {
    CodeBlockView(
        language: "swift",
        code: """
        struct Greeter {
            let name: String

            func greet() -> String {
                "Merhaba, \\(name)! Bu satır yatay kaydırmayı test edecek kadar uzun bir satırdır."
            }
        }
        """
    )
    .padding()
    .frame(width: 480)
}
