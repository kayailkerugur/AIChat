//
//  MarkdownContentParser.swift
//  AIChatSDK
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//

import Foundation

enum MarkdownSegment: Equatable {
    case text(String)
    case codeBlock(language: String?, code: String)
}

enum MarkdownContentParser {

    static func parse(_ content: String) -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []

        var textLines: [String] = []
        var codeLines: [String] = []
        var currentLanguage: String?
        var insideCode = false

        func flushText() {
            let text = textLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                segments.append(.text(text))
            }
            textLines = []
        }

        func flushCode() {
            segments.append(.codeBlock(
                language: currentLanguage,
                code: codeLines.joined(separator: "\n")
            ))
            codeLines = []
            currentLanguage = nil
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if insideCode {
                    // Closing fence.
                    flushCode()
                    insideCode = false
                } else {
                    // Opening fence — optional language tag after the backticks.
                    flushText()
                    let language = trimmed
                        .dropFirst(3)
                        .trimmingCharacters(in: .whitespaces)
                    currentLanguage = language.isEmpty ? nil : language
                    insideCode = true
                }
                continue
            }

            if insideCode {
                codeLines.append(String(line))
            } else {
                textLines.append(String(line))
            }
        }

        // End of content:
        // - leftover text → text segment
        // - unclosed fence (mid-stream!) → emit what we have as code
        if insideCode {
            flushCode()
        } else {
            flushText()
        }

        return segments
    }
}
