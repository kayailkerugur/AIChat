import AIChatSDK
import Foundation
import XCTest
@testable import AIChat

final class AppRepositoryProviderTests: XCTestCase {
    func test_missingRepositoryConfigurationIsRejected() async {
        let defaults = isolatedDefaults()
        let provider = AppRepositoryProvider(
            configuration: .init(mode: .code),
            defaults: defaults
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

    func test_developerURLCreatesFixedRepositoryClient() async throws {
        let defaults = isolatedDefaults()
        let url = URL(fileURLWithPath: "/tmp/developer-repository")
        let provider = AppRepositoryProvider(
            configuration: .init(
                mode: .code,
                repositoryURL: url
            ),
            defaults: defaults
        )

        let client = try await provider.activeRepositoryClient()

        XCTAssertEqual(client.repository.rootURL, url)
        XCTAssertEqual(client.repository.displayName, "developer-repository")
    }

    func test_clearRepositoryRemovesPersistedBookmark() async {
        let defaults = isolatedDefaults()
        defaults.set(
            Data("bookmark".utf8),
            forKey: AppRepositoryProvider.bookmarkKey
        )
        let provider = AppRepositoryProvider(
            configuration: .init(mode: .code),
            defaults: defaults
        )

        await provider.clearRepository()

        XCTAssertNil(
            defaults.data(forKey: AppRepositoryProvider.bookmarkKey)
        )
    }

    func test_repositoryBookmarksAreScopedToConversation() async throws {
        let defaults = isolatedDefaults()
        let firstConversationID = UUID()
        let secondConversationID = UUID()
        let firstURL = try temporaryDirectory(named: "first-repository")
        let secondURL = try temporaryDirectory(named: "second-repository")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let provider = AppRepositoryProvider(
            configuration: .init(mode: .code),
            defaults: defaults
        )

        try await provider.selectRepository(
            at: firstURL,
            for: firstConversationID
        )
        try await provider.selectRepository(
            at: secondURL,
            for: secondConversationID
        )

        XCTAssertNotNil(defaults.data(
            forKey: AppRepositoryProvider.bookmarkKey(
                for: firstConversationID
            )
        ))
        XCTAssertNotNil(defaults.data(
            forKey: AppRepositoryProvider.bookmarkKey(
                for: secondConversationID
            )
        ))
        XCTAssertNotEqual(
            AppRepositoryProvider.bookmarkKey(for: firstConversationID),
            AppRepositoryProvider.bookmarkKey(for: secondConversationID)
        )
    }

    func test_repositoryBookmarksAreScopedToProject() async throws {
        let defaults = isolatedDefaults()
        let firstProjectID = UUID()
        let secondProjectID = UUID()
        let firstURL = try temporaryDirectory(named: "first-project")
        let secondURL = try temporaryDirectory(named: "second-project")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let provider = AppRepositoryProvider(
            configuration: .init(mode: .code),
            defaults: defaults
        )

        try await provider.selectRepository(
            at: firstURL,
            forProject: firstProjectID
        )
        try await provider.selectRepository(
            at: secondURL,
            forProject: secondProjectID
        )

        let firstKey = AppRepositoryProvider.bookmarkKey(
            forProject: firstProjectID
        )
        let secondKey = AppRepositoryProvider.bookmarkKey(
            forProject: secondProjectID
        )
        XCTAssertNotNil(defaults.data(forKey: firstKey))
        XCTAssertNotNil(defaults.data(forKey: secondKey))
        XCTAssertNotEqual(firstKey, secondKey)
    }

    func test_missingConversationBookmarkDoesNotUseGlobalBookmark() async {
        let defaults = isolatedDefaults()
        defaults.set(
            Data("legacy-global-bookmark".utf8),
            forKey: AppRepositoryProvider.bookmarkKey
        )
        let provider = AppRepositoryProvider(
            configuration: .init(mode: .code),
            defaults: defaults
        )

        do {
            _ = try await provider.repositoryClient(for: UUID())
            XCTFail("Expected conversation-scoped invalidBookmark")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .invalidBookmark)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "AppRepositoryProviderTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    private func temporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "\(name)-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

}
