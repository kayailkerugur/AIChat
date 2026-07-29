import AIChatSDK
import Foundation

/// App-owned persistence adapter for the SDK's repository abstraction.
///
/// The SDK owns bookmark creation and secure resolution. The host application
/// decides where bookmark data is persisted and when a folder picker appears.
actor AppRepositoryProvider: RepositoryProvider {
    static let bookmarkKey = "AIChat.codeMode.repositoryBookmark"

    private var bookmarkData: Data?
    private var fallbackURL: URL?
    private let forcedError: RepositoryError?
    private let defaults: UserDefaults

    init(
        configuration: AppSDKConfiguration,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        bookmarkData = configuration.repositoryBookmarkData
            ?? defaults.data(forKey: Self.bookmarkKey)
        fallbackURL = configuration.repositoryURL
        forcedError = configuration.repositoryError
    }

    func activeRepositoryClient() async throws -> any RepositoryClient {
        if let forcedError { throw forcedError }
        if let bookmarkData {
            return try await SecurityScopedRepositoryProvider(
                bookmarkData: bookmarkData
            ).activeRepositoryClient()
        }
        if let fallbackURL {
            return try await FixedRepositoryProvider(
                rootURL: fallbackURL
            ).activeRepositoryClient()
        }
        throw RepositoryError.invalidBookmark
    }

    func repositoryClient(
        forProject projectID: UUID
    ) async throws -> any RepositoryClient {
        if let forcedError { throw forcedError }
        if let data = defaults.data(
            forKey: Self.bookmarkKey(forProject: projectID)
        ) {
            return try await SecurityScopedRepositoryProvider(
                bookmarkData: data
            ).activeRepositoryClient()
        }
        if let fallbackURL {
            return try await FixedRepositoryProvider(
                rootURL: fallbackURL
            ).activeRepositoryClient()
        }
        throw RepositoryError.invalidBookmark
    }

    func repositoryClient(
        for conversationID: UUID
    ) async throws -> any RepositoryClient {
        if let forcedError { throw forcedError }
        if let data = defaults.data(
            forKey: Self.bookmarkKey(for: conversationID)
        ) {
            return try await SecurityScopedRepositoryProvider(
                bookmarkData: data
            ).activeRepositoryClient()
        }
        if let fallbackURL {
            return try await FixedRepositoryProvider(
                rootURL: fallbackURL
            ).activeRepositoryClient()
        }
        throw RepositoryError.invalidBookmark
    }

    func selectRepository(at url: URL) throws {
        let data = try RepositoryBookmark.create(for: url)
        bookmarkData = data
        fallbackURL = nil
        defaults.set(data, forKey: Self.bookmarkKey)
    }

    func selectRepository(
        at url: URL,
        forProject projectID: UUID
    ) throws {
        let data = try RepositoryBookmark.create(for: url)
        defaults.set(data, forKey: Self.bookmarkKey(forProject: projectID))
    }

    func selectRepository(
        at url: URL,
        for conversationID: UUID
    ) throws {
        let data = try RepositoryBookmark.create(for: url)
        defaults.set(data, forKey: Self.bookmarkKey(for: conversationID))
    }

    func clearRepository() {
        bookmarkData = nil
        fallbackURL = nil
        defaults.removeObject(forKey: Self.bookmarkKey)
    }

    func clearRepository(for conversationID: UUID) {
        defaults.removeObject(
            forKey: Self.bookmarkKey(for: conversationID)
        )
    }

    func clearRepository(forProject projectID: UUID) {
        defaults.removeObject(
            forKey: Self.bookmarkKey(forProject: projectID)
        )
    }

    static func bookmarkKey(forProject projectID: UUID) -> String {
        "\(bookmarkKey).project.\(projectID.uuidString)"
    }

    static func bookmarkKey(for conversationID: UUID) -> String {
        "\(bookmarkKey).conversation.\(conversationID.uuidString)"
    }
}
