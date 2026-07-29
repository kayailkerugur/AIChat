import Foundation

/// Creates persistent bookmark data after the host application has obtained a
/// user-selected URL (for example, through `NSOpenPanel`).
public enum RepositoryBookmark {
    public static func create(for url: URL) throws -> Data {
        guard url.isFileURL else {
            throw RepositoryError.invalidDirectory
        }
        do {
            return try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw RepositoryError.invalidBookmark
        }
    }
}

/// Resolves a persistent security-scoped bookmark into a read-only repository
/// client. Access remains active for the lifetime of the returned client.
public struct SecurityScopedRepositoryProvider: RepositoryProvider {
    private let bookmarkData: Data
    private let displayName: String?

    public init(
        bookmarkData: Data,
        displayName: String? = nil
    ) {
        self.bookmarkData = bookmarkData
        self.displayName = displayName
    }

    public func activeRepositoryClient() async throws -> any RepositoryClient {
        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw RepositoryError.invalidBookmark
        }

        guard !isStale else {
            throw RepositoryError.staleBookmark
        }
        guard url.startAccessingSecurityScopedResource() else {
            throw RepositoryError.securityScopedAccessDenied
        }

        let access = SecurityScopedAccess(url: url)
        let repository = RepositoryDescriptor(
            displayName: displayName ?? url.lastPathComponent,
            rootURL: url
        )
        return SecurityScopedRepositoryClient(
            client: LocalGitRepositoryClient(repository: repository),
            access: access
        )
    }
}

private final class SecurityScopedAccess: @unchecked Sendable {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    deinit {
        url.stopAccessingSecurityScopedResource()
    }
}

private final class SecurityScopedRepositoryClient: RepositoryClient, Sendable {
    let repository: RepositoryDescriptor

    private let client: LocalGitRepositoryClient
    private let access: SecurityScopedAccess

    init(
        client: LocalGitRepositoryClient,
        access: SecurityScopedAccess
    ) {
        self.client = client
        self.access = access
        repository = client.repository
    }

    func status() async throws -> RepositoryStatus {
        _ = access
        return try await client.status()
    }

    func diff(for change: RepositoryChange) async throws -> String {
        _ = access
        return try await client.diff(for: change)
    }

    func files() async throws -> [RepositoryFile] {
        _ = access
        return try await client.files()
    }

    func readFile(
        at path: String,
        maximumByteCount: Int
    ) async throws -> RepositoryFileContent {
        _ = access
        return try await client.readFile(
            at: path,
            maximumByteCount: maximumByteCount
        )
    }
}
