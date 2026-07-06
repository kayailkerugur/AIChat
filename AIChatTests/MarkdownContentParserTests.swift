//
//  MarkdownContentParserTests.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//

import XCTest
@testable import AIChat

final class MarkdownContentParserTests: XCTestCase {

    func test_plainText_returnsSingleTextSegment() {
        let segments = MarkdownContentParser.parse("Merhaba dünya")

        XCTAssertEqual(segments, [.text("Merhaba dünya")])
    }

    func test_emptyContent_returnsNoSegments() {
        XCTAssertTrue(MarkdownContentParser.parse("").isEmpty)
        XCTAssertTrue(MarkdownContentParser.parse("   \n  ").isEmpty)
    }

    func test_singleCodeBlock_capturesLanguageAndCode() {
        let content = """
        ```swift
        let x = 1
        ```
        """

        let segments = MarkdownContentParser.parse(content)

        XCTAssertEqual(segments, [.codeBlock(language: "swift", code: "let x = 1")])
    }

    func test_codeBlockWithoutLanguage_hasNilLanguage() {
        let content = """
        ```
        plain code
        ```
        """

        let segments = MarkdownContentParser.parse(content)

        XCTAssertEqual(segments, [.codeBlock(language: nil, code: "plain code")])
    }

    func test_textAroundCodeBlock_producesThreeSegmentsInOrder() {
        let content = """
        Önce açıklama.

        ```swift
        print("merhaba")
        ```

        Sonra devam.
        """

        let segments = MarkdownContentParser.parse(content)

        XCTAssertEqual(segments, [
            .text("Önce açıklama."),
            .codeBlock(language: "swift", code: "print(\"merhaba\")"),
            .text("Sonra devam."),
        ])
    }

    func test_multilineCode_preservesInternalNewlinesAndIndentation() {
        let content = """
        ```swift
        struct A {
            let x: Int
        }
        ```
        """

        let segments = MarkdownContentParser.parse(content)

        XCTAssertEqual(segments, [
            .codeBlock(language: "swift", code: "struct A {\n    let x: Int\n}"),
        ])
    }

    /// Streaming scenario: the closing fence has not arrived yet.
    /// The parser must already treat the accumulated lines as code,
    /// otherwise the UI shows raw ``` marks mid-stream.
    func test_unclosedFence_isEmittedAsCodeSegment() {
        let content = """
        İşte kod:

        ```swift
        let partial = true
        """

        let segments = MarkdownContentParser.parse(content)

        XCTAssertEqual(segments, [
            .text("İşte kod:"),
            .codeBlock(language: "swift", code: "let partial = true"),
        ])
    }

    func test_multipleCodeBlocks_areAllCaptured() {
        let content = """
        ```swift
        let a = 1
        ```
        Ara metin.
        ```python
        b = 2
        ```
        """

        let segments = MarkdownContentParser.parse(content)

        XCTAssertEqual(segments, [
            .codeBlock(language: "swift", code: "let a = 1"),
            .text("Ara metin."),
            .codeBlock(language: "python", code: "b = 2"),
        ])
    }
}
