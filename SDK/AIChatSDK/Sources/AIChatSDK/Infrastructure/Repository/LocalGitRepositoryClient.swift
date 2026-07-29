import Foundation

/// Read-only Git repository client.
///
/// Git data is read in-process through libgit2 so the client works inside an
/// App Sandbox without launching `git`, `xcrun`, or a shell.
public final class LocalGitRepositoryClient: RepositoryClient, Sendable {
    public let repository: RepositoryDescriptor

    public init(repository: RepositoryDescriptor) {
        self.repository = repository
    }

    public convenience init(rootURL: URL, displayName: String? = nil) {
        self.init(repository: RepositoryDescriptor(
            displayName: displayName ?? rootURL.lastPathComponent,
            rootURL: rootURL
        ))
    }

    public func status() async throws -> RepositoryStatus {
        let repository = repository
        return try await Task.detached(priority: .utility) {
            let handle = try GitRepositoryHandle(opening: repository.rootURL)
            let rootURL = handle.rootURL
            let head = try handle.head()
            let lastCommit = handle.lastCommit()

            return RepositoryStatus(
                repository: RepositoryDescriptor(
                    id: repository.id,
                    displayName: repository.displayName,
                    rootURL: rootURL
                ),
                branchName: head.branchName,
                headRevision: head.revision,
                remoteURL: handle.remoteURL(),
                lastCommitSummary: lastCommit?.summary,
                lastCommitAuthor: lastCommit?.author,
                lastCommitDate: lastCommit?.date,
                changes: try handle.changes()
            )
        }.value
    }

    public func diff(for change: RepositoryChange) async throws -> String {
        let repository = repository
        return try await Task.detached(priority: .utility) {
            try Self.validate(
                changePath: change.path,
                within: repository.rootURL.standardizedFileURL
            )
            let handle = try GitRepositoryHandle(opening: repository.rootURL)
            let rootURL = handle.rootURL
            try Self.validate(changePath: change.path, within: rootURL)
            return try handle.diff(for: change)
        }.value
    }

    public func files() async throws -> [RepositoryFile] {
        let repository = repository
        return try await Task.detached(priority: .utility) {
            let handle = try GitRepositoryHandle(opening: repository.rootURL)
            return try handle.files()
                .map(RepositoryFile.init(path:))
                .sorted {
                    $0.path.localizedStandardCompare($1.path) == .orderedAscending
                }
        }.value
    }

    public func readFile(
        at path: String,
        maximumByteCount: Int = 200_000
    ) async throws -> RepositoryFileContent {
        let repository = repository
        return try await Task.detached(priority: .utility) {
            let rootURL = try GitRepositoryHandle(
                opening: repository.rootURL
            ).rootURL
            let fileURL = try Self.validatedFileURL(
                path: path,
                within: rootURL
            )
            let limit = max(0, maximumByteCount)
            guard limit > 0 else {
                throw RepositoryError.fileTooLarge
            }

            let values = try fileURL.resourceValues(
                forKeys: [.fileSizeKey, .isRegularFileKey]
            )
            guard values.isRegularFile == true else {
                throw RepositoryError.fileNotFound
            }

            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: limit + 1) ?? Data()
            guard !data.contains(0) else {
                throw RepositoryError.binaryFileUnsupported
            }

            let wasTruncated = (values.fileSize ?? data.count) > limit
            let visibleData = data.prefix(limit)
            guard let content = String(data: visibleData, encoding: .utf8) else {
                throw RepositoryError.binaryFileUnsupported
            }
            let redacted = RepositorySecretRedactor.redact(content)

            return RepositoryFileContent(
                file: RepositoryFile(path: path),
                content: redacted.content,
                wasTruncated: wasTruncated,
                containsRedactions: redacted.changed
            )
        }.value
    }

    private static func validatedRootURL(_ rootURL: URL) throws -> URL {
        guard rootURL.isFileURL else {
            throw RepositoryError.invalidDirectory
        }

        let standardizedURL = rootURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: standardizedURL.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            throw RepositoryError.invalidDirectory
        }
        return standardizedURL
    }

    private static func validate(changePath: String, within rootURL: URL) throws {
        guard !changePath.isEmpty,
              !changePath.hasPrefix("/"),
              !changePath.split(separator: "/", omittingEmptySubsequences: false)
                .contains(where: { $0 == ".." })
        else {
            throw RepositoryError.invalidPath
        }

        let rootPath = rootURL.standardizedFileURL.path
        let candidatePath = rootURL
            .appendingPathComponent(changePath)
            .standardizedFileURL
            .path
        guard candidatePath.hasPrefix(rootPath + "/") else {
            throw RepositoryError.invalidPath
        }
    }

    private static func validatedFileURL(
        path: String,
        within rootURL: URL
    ) throws -> URL {
        try validate(changePath: path, within: rootURL)

        let candidateURL = rootURL.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: candidateURL.path) else {
            throw RepositoryError.fileNotFound
        }

        let resourceValues = try candidateURL.resourceValues(
            forKeys: [.isSymbolicLinkKey]
        )
        guard resourceValues.isSymbolicLink != true else {
            throw RepositoryError.symbolicLinkUnsupported
        }

        let rootPath = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let resolvedPath = candidateURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        guard resolvedPath.hasPrefix(rootPath + "/") else {
            throw RepositoryError.invalidPath
        }
        return candidateURL
    }

}
