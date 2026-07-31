import AIChatSDK
import XCTest
@testable import AIChat

@MainActor
final class ProjectContextFilesViewModelTests: XCTestCase {
    func test_loadFiltersContextFilesAndSaveWritesSelectedFile() async {
        let client = ContextFileClient()
        let viewModel = ProjectContextFilesViewModel(
            repositoryProvider: ContextFileProvider(client: client),
            projectID: UUID()
        )

        await viewModel.load()

        XCTAssertEqual(
            viewModel.files.map(\.path),
            ["AGENTS.md", "README.md"]
        )
        XCTAssertEqual(viewModel.selectedFile?.path, "AGENTS.md")
        XCTAssertEqual(viewModel.content, "Initial context")

        viewModel.content = "Updated context"
        XCTAssertTrue(viewModel.canSave)
        await viewModel.save()

        XCTAssertEqual(client.writtenPath, "AGENTS.md")
        XCTAssertEqual(client.writtenContent, "Updated context")
        XCTAssertFalse(viewModel.hasChanges)
    }
}

private struct ContextFileProvider: RepositoryProvider {
    let client: ContextFileClient

    func activeRepositoryClient() async throws -> any RepositoryClient {
        client
    }

    func repositoryClient(
        forProject projectID: UUID
    ) async throws -> any RepositoryClient {
        client
    }
}

private final class ContextFileClient:
    RepositoryContextFileWriting,
    @unchecked Sendable
{
    let repository = RepositoryDescriptor(
        displayName: "Fixture",
        rootURL: URL(fileURLWithPath: "/tmp/fixture")
    )
    var writtenPath: String?
    var writtenContent: String?

    func status() async throws -> RepositoryStatus {
        RepositoryStatus(
            repository: repository,
            branchName: "main",
            headRevision: nil,
            changes: []
        )
    }

    func diff(for change: RepositoryChange) async throws -> String {
        ""
    }

    func files() async throws -> [RepositoryFile] {
        [
            RepositoryFile(path: "Sources/App.swift"),
            RepositoryFile(path: "README.md"),
            RepositoryFile(path: "AGENTS.md")
        ]
    }

    func readFile(
        at path: String,
        maximumByteCount: Int
    ) async throws -> RepositoryFileContent {
        try await readContextFile(
            at: path,
            maximumByteCount: maximumByteCount
        )
    }

    func readContextFile(
        at path: String,
        maximumByteCount: Int
    ) async throws -> RepositoryFileContent {
        RepositoryFileContent(
            file: RepositoryFile(path: path),
            content: "Initial context",
            wasTruncated: false,
            containsRedactions: false
        )
    }

    func writeContextFile(
        at path: String,
        content: String,
        maximumByteCount: Int
    ) async throws {
        writtenPath = path
        writtenContent = content
    }
}
