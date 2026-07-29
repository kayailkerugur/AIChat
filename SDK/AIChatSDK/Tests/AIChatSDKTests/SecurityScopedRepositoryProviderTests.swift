import Foundation
import XCTest
@testable import AIChatSDK

final class SecurityScopedRepositoryProviderTests: XCTestCase {
    func test_invalidBookmarkDataIsRejected() async {
        let provider = SecurityScopedRepositoryProvider(
            bookmarkData: Data("not-a-bookmark".utf8)
        )

        do {
            _ = try await provider.activeRepositoryClient()
            XCTFail("Expected invalidBookmark")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .invalidBookmark)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_nonFileURLCannotCreateRepositoryBookmark() {
        let url = URL(string: "https://example.com/repository")!

        XCTAssertThrowsError(try RepositoryBookmark.create(for: url)) { error in
            XCTAssertEqual(error as? RepositoryError, .invalidDirectory)
        }
    }
}
