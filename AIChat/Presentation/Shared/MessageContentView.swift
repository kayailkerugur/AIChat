//
//  MessageContentView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//

import SwiftUI

struct MessageContentView: View {

    let content: String

    var body: some View {
        let segments = MarkdownContentParser.parse(content)

        VStack(alignment: .leading, spacing: 8) {
            ForEach(segments.indices, id: \.self) { index in
                switch segments[index] {
                case .text(let text):
                    Text(attributed(text))
                        .textSelection(.enabled)

                case .codeBlock(let language, let code):
                    CodeBlockView(language: language, code: code)
                }
            }
        }
    }

    private func attributed(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
        // Fallback: malformed markdown should never break rendering —
        // worst case the user sees the raw text.
    }
}

#Preview {
    MessageContentView(
        content: """
        İşte **kalın**, *italik* ve `inline kod` örnekleri.

        ```swift
        let greeting = "Merhaba"
        print(greeting)
        ```

        Kod bloğundan sonra devam eden metin.
        """
    )
    .padding()
    .frame(width: 480)
}
