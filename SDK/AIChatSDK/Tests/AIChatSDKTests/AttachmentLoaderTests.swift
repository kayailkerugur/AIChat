import Foundation
import XCTest
@testable import AIChatSDK

final class AttachmentLoaderTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
    }

    func testLoadsPlainTextAsDocumentAndExtractsText() throws {
        let url = temporaryDirectory.appendingPathComponent("notes.txt")
        let data = Data("Hello from attachment".utf8)
        try data.write(to: url)

        let attachment = try AttachmentLoader.load(from: url)

        XCTAssertEqual(attachment.fileName, "notes.txt")
        XCTAssertEqual(attachment.mimeType, "text/plain")
        XCTAssertEqual(attachment.kind, .document)
        XCTAssertEqual(attachment.data, data)
        XCTAssertEqual(attachment.extractedText, "Hello from attachment")
    }

    func testLoadsImageWithoutTextExtraction() throws {
        let url = temporaryDirectory.appendingPathComponent("image.png")
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        try data.write(to: url)

        let attachment = try AttachmentLoader.load(from: url)

        XCTAssertEqual(attachment.mimeType, "image/png")
        XCTAssertEqual(attachment.kind, .image)
        XCTAssertEqual(attachment.data, data)
        XCTAssertNil(attachment.extractedText)
    }
}
