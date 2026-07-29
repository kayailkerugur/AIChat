import Foundation

/// Supplies the repository selected by the integrating application.
/// The SDK does not present a repository picker or persist sandbox bookmarks.
public protocol RepositoryProvider: Sendable {
    func activeRepositoryClient() async throws -> any RepositoryClient
    func repositoryClient(
        forProject projectID: UUID
    ) async throws -> any RepositoryClient
    func repositoryClient(
        for conversationID: UUID
    ) async throws -> any RepositoryClient
}

public extension RepositoryProvider {
    /// Project-aware resolution used by Code Mode. One project owns one
    /// repository and all conversations in that project share it.
    func repositoryClient(
        forProject projectID: UUID
    ) async throws -> any RepositoryClient {
        try await activeRepositoryClient()
    }

    /// Conversation-aware resolution used by Code Mode. Providers that do not
    /// persist scoped state retain their existing behavior. This remains as a
    /// compatibility path for conversations not assigned to a project yet.
    func repositoryClient(
        for conversationID: UUID
    ) async throws -> any RepositoryClient {
        try await activeRepositoryClient()
    }
}

/// Read-only access to repository state used by code mode.
public protocol RepositoryClient: Sendable {
    var repository: RepositoryDescriptor { get }

    func status() async throws -> RepositoryStatus
    func diff(for change: RepositoryChange) async throws -> String
    func files() async throws -> [RepositoryFile]
    func readFile(
        at path: String,
        maximumByteCount: Int
    ) async throws -> RepositoryFileContent
}

public extension RepositoryClient {
    func files() async throws -> [RepositoryFile] {
        throw RepositoryError.fileAccessUnsupported
    }

    func readFile(
        at path: String,
        maximumByteCount: Int
    ) async throws -> RepositoryFileContent {
        throw RepositoryError.fileAccessUnsupported
    }
}

public struct FixedRepositoryProvider: RepositoryProvider {
    private let repository: RepositoryDescriptor

    public init(repository: RepositoryDescriptor) {
        self.repository = repository
    }

    public init(rootURL: URL, displayName: String? = nil) {
        repository = RepositoryDescriptor(
            displayName: displayName ?? rootURL.lastPathComponent,
            rootURL: rootURL
        )
    }

    public func activeRepositoryClient() async throws -> any RepositoryClient {
        LocalGitRepositoryClient(repository: repository)
    }
}
