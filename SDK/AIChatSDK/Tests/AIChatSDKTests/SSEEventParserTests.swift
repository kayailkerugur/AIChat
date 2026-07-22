import XCTest
@testable import AIChatSDK

final class SSEEventParserTests: XCTestCase {
    func testSingleDataLineDispatchesOnBlankLine() {
        var parser = SSEEventParser()
        XCTAssertNil(parser.feed(line: #"data: {"text":"merhaba"}"#))
        XCTAssertEqual(parser.feed(line: ""), #"{"text":"merhaba"}"#)
    }

    func testLeadingSpaceAfterColonStripsOnlyOneSpace() {
        var parser = SSEEventParser()
        _ = parser.feed(line: "data:  double-space")
        XCTAssertEqual(parser.feed(line: ""), " double-space")
    }

    func testMultipleDataLinesJoinWithNewline() {
        var parser = SSEEventParser()
        XCTAssertNil(parser.feed(line: "data: satır1"))
        XCTAssertNil(parser.feed(line: "data: satır2"))
        XCTAssertEqual(parser.feed(line: ""), "satır1\nsatır2")
    }

    func testCommentsAndUnknownFieldsAreIgnored() {
        var parser = SSEEventParser()
        XCTAssertNil(parser.feed(line: ": keep-alive"))
        XCTAssertNil(parser.feed(line: "event: message"))
        XCTAssertNil(parser.feed(line: "id: 42"))
        XCTAssertNil(parser.feed(line: "data: içerik"))
        XCTAssertEqual(parser.feed(line: ""), "içerik")
    }

    func testBlankLineWithoutPendingDataReturnsNil() {
        var parser = SSEEventParser()
        XCTAssertNil(parser.feed(line: ""))
        XCTAssertNil(parser.feed(line: ""))
    }

    func testConsecutiveEventsDispatchSeparately() {
        var parser = SSEEventParser()
        _ = parser.feed(line: "data: bir")
        XCTAssertEqual(parser.feed(line: ""), "bir")
        _ = parser.feed(line: "data: iki")
        XCTAssertEqual(parser.feed(line: ""), "iki")
    }

    func testFlushPendingReturnsTrailingEventOnce() {
        var parser = SSEEventParser()
        _ = parser.feed(line: "data: son event")
        XCTAssertEqual(parser.flushPending(), "son event")
        XCTAssertNil(parser.flushPending())
    }
}
