import Foundation
import XCTest
@testable import AIChatSDK

final class AttachmentFileStoreTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var store: AttachmentFileStore!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = AttachmentFileStore(rootDirectory: temporaryDirectory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
        store = nil
    }

    func testWriteAndReadRoundTrip() throws {
        let data = Data("attachment contents".utf8)
        let attachmentID = UUID()
        let messageID = UUID()

        let relativePath = try store.write(
            data: data,
            fileName: "notes.txt",
            attachmentID: attachmentID,
            messageID: messageID
        )

        XCTAssertEqual(
            relativePath,
            "\(messageID.uuidString)/\(attachmentID.uuidString)-notes.txt"
        )
        XCTAssertEqual(store.read(relativePath: relativePath), data)
    }

    func testWriteSanitizesFileName() throws {
        let relativePath = try store.write(
            data: Data(),
            fileName: "folder/report:\nfinal.txt",
            attachmentID: UUID(),
            messageID: UUID()
        )

        XCTAssertTrue(relativePath.hasSuffix("-folder-report--final.txt"))
        XCTAssertEqual(relativePath.split(separator: "/").count, 2)
    }

    func testDeleteRemovesFileAndEmptyMessageDirectory() throws {
        let relativePath = try store.write(
            data: Data("data".utf8),
            fileName: "file.txt",
            attachmentID: UUID(),
            messageID: UUID()
        )
        let messageDirectory = temporaryDirectory
            .appendingPathComponent(String(relativePath.split(separator: "/")[0]))

        store.delete(relativePath: relativePath)

        XCTAssertNil(store.read(relativePath: relativePath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: messageDirectory.path))
    }
}
