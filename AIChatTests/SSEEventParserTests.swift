//
//  SSEEventParserTests.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//

import XCTest
@testable import AIChat

final class SSEEventParserTests: XCTestCase {

    func test_singleDataLine_dispatchesOnBlankLine() {
        var parser = SSEEventParser()

        XCTAssertNil(parser.feed(line: #"data: {"text":"merhaba"}"#))
        XCTAssertEqual(parser.feed(line: ""), #"{"text":"merhaba"}"#)
    }

    func test_leadingSpaceAfterColon_isStripped_butOnlyOne() {
        var parser = SSEEventParser()

        _ = parser.feed(line: "data:  double-space")
        // First space stripped per spec; second one belongs to the payload.
        XCTAssertEqual(parser.feed(line: ""), " double-space")
    }

    func test_multipleDataLines_joinWithNewline() {
        var parser = SSEEventParser()

        XCTAssertNil(parser.feed(line: "data: satır1"))
        XCTAssertNil(parser.feed(line: "data: satır2"))
        XCTAssertEqual(parser.feed(line: ""), "satır1\nsatır2")
    }

    func test_commentLines_areIgnored() {
        var parser = SSEEventParser()

        XCTAssertNil(parser.feed(line: ": keep-alive"))
        XCTAssertNil(parser.feed(line: "data: gerçek veri"))
        XCTAssertEqual(parser.feed(line: ""), "gerçek veri")
    }

    func test_unknownFields_areIgnored() {
        var parser = SSEEventParser()

        XCTAssertNil(parser.feed(line: "event: message"))
        XCTAssertNil(parser.feed(line: "id: 42"))
        XCTAssertNil(parser.feed(line: "data: içerik"))
        XCTAssertEqual(parser.feed(line: ""), "içerik")
    }

    func test_blankLineWithoutPendingData_returnsNil() {
        var parser = SSEEventParser()

        XCTAssertNil(parser.feed(line: ""))
        XCTAssertNil(parser.feed(line: ""))
    }

    func test_consecutiveEvents_areDispatchedSeparately() {
        var parser = SSEEventParser()

        _ = parser.feed(line: "data: bir")
        XCTAssertEqual(parser.feed(line: ""), "bir")
        _ = parser.feed(line: "data: iki")
        XCTAssertEqual(parser.feed(line: ""), "iki")
    }

    func test_flushPending_returnsTrailingEventWithoutBlankLine() {
        var parser = SSEEventParser()

        _ = parser.feed(line: "data: son event")
        XCTAssertEqual(parser.flushPending(), "son event")
        XCTAssertNil(parser.flushPending(), "flush is one-shot")
    }
}
