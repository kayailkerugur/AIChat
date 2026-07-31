import Foundation
import XCTest
@testable import AIChatSDK

@MainActor
final class CodeModeViewModelTests: XCTestCase {
    func test_standardModeRejectsCodeModelWithoutResolvingProvider() async throws {
        let store = InMemoryChatRepository()
        let repositoryClient = RepositoryClientStub()
        let provider = RepositoryProviderStub(client: repositoryClient)
        let client = AIChatClient(
            configuration: .init(mode: .standard),
            providerRegistry: CodeModeProviderRegistryStub(),
            conversationRepository: store,
            messageRepository: store,
            repositoryProvider: provider
        )

        XCTAssertThrowsError(try client.makeCodeModeViewModel()) { error in
            XCTAssertEqual(
                error as? AIChatClientConfigurationError,
                .codeModeRequired
            )
        }
        let resolutionCount = await provider.resolutionCount
        XCTAssertEqual(resolutionCount, 0)
    }

    func test_codeModeRequiresRepositoryProvider() {
        let store = InMemoryChatRepository()
        let client = AIChatClient(
            configuration: .init(mode: .code),
            providerRegistry: CodeModeProviderRegistryStub(),
            conversationRepository: store,
            messageRepository: store
        )

        XCTAssertThrowsError(try client.makeCodeModeViewModel()) { error in
            XCTAssertEqual(
                error as? AIChatClientConfigurationError,
                .repositoryProviderRequired
            )
        }
    }

    func test_loadAndSelectExposeRepositoryStatusAndDiff() async throws {
        let change = RepositoryChange(
            path: "Sources/App.swift",
            status: .modified,
            area: .unstaged
        )
        let repositoryClient = RepositoryClientStub(
            changes: [change],
            diffs: [change.id: "+updated"]
        )
        let provider = RepositoryProviderStub(client: repositoryClient)
        let viewModel = CodeModeViewModel(repositoryProvider: provider)

        await viewModel.load()
        await viewModel.select(change)

        XCTAssertEqual(viewModel.repositoryStatus?.branchName, "sdk-v2")
        XCTAssertEqual(viewModel.repositoryStatus?.changes, [change])
        XCTAssertEqual(viewModel.selectedChange, change)
        XCTAssertEqual(viewModel.selectedDiff, "+updated")
        XCTAssertNil(viewModel.errorMessage)
        let resolutionCount = await provider.resolutionCount
        XCTAssertEqual(resolutionCount, 1)
    }

    func test_projectConversationResolvesRepositoryByProject() async throws {
        let projectID = UUID()
        let repositoryClient = RepositoryClientStub()
        let provider = RepositoryProviderStub(client: repositoryClient)
        let viewModel = CodeModeViewModel(
            repositoryProvider: provider,
            projectID: projectID,
            conversationID: UUID()
        )

        await viewModel.load()

        let resolvedProjectID = await provider.resolvedProjectID
        let resolvedConversationID = await provider.resolvedConversationID
        XCTAssertEqual(resolvedProjectID, projectID)
        XCTAssertNil(resolvedConversationID)
    }

    func test_refreshClearsSelectionWhenChangeNoLongerExists() async {
        let change = RepositoryChange(
            path: "Sources/App.swift",
            status: .modified,
            area: .unstaged
        )
        let repositoryClient = RepositoryClientStub(
            statusChanges: [[change], []],
            diffs: [change.id: "+updated"]
        )
        let viewModel = CodeModeViewModel(
            repositoryProvider: RepositoryProviderStub(client: repositoryClient)
        )

        await viewModel.load()
        await viewModel.select(change)
        await viewModel.refresh()

        XCTAssertTrue(viewModel.repositoryStatus?.changes.isEmpty == true)
        XCTAssertNil(viewModel.selectedChange)
        XCTAssertTrue(viewModel.selectedDiff.isEmpty)
    }

    func test_refreshExposesNewRepositoryChanges() async {
        let newChange = RepositoryChange(
            path: "Sources/NewFile.swift",
            status: .untracked,
            area: .untracked
        )
        let repositoryClient = RepositoryClientStub(
            statusChanges: [[], [newChange]]
        )
        let viewModel = CodeModeViewModel(
            repositoryProvider: RepositoryProviderStub(
                client: repositoryClient
            )
        )

        await viewModel.load()
        XCTAssertTrue(
            viewModel.repositoryStatus?.changes.isEmpty == true
        )

        await viewModel.refresh()

        XCTAssertEqual(
            viewModel.repositoryStatus?.changes,
            [newChange]
        )
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_contextIncludesRepositoryAndTruncatesSelectedDiff() async {
        let change = RepositoryChange(
            path: "Sources/App.swift",
            status: .modified,
            area: .unstaged
        )
        let repositoryClient = RepositoryClientStub(
            changes: [change],
            diffs: [change.id: "123456789"]
        )
        let viewModel = CodeModeViewModel(
            repositoryProvider: RepositoryProviderStub(
                client: repositoryClient
            ),
            contextCharacterLimit: 5
        )

        await viewModel.load()
        await viewModel.select(change)
        let context = viewModel.contextMessages()

        XCTAssertEqual(context.count, 1)
        XCTAssertEqual(context[0].role, .system)
        XCTAssertTrue(context[0].content.contains("branch: sdk-v2"))
        XCTAssertTrue(context[0].content.contains("12345"))
        XCTAssertFalse(context[0].content.contains("123456"))
        XCTAssertTrue(context[0].content.contains("5 karakterde kesildi"))
    }

    func test_contextIsEmptyUntilRepositoryLoads() {
        let viewModel = CodeModeViewModel(
            repositoryProvider: RepositoryProviderStub(
                client: RepositoryClientStub()
            )
        )

        XCTAssertTrue(viewModel.contextMessages().isEmpty)
    }

    func test_missingBookmarkRequestsRepositorySelection() async {
        let viewModel = CodeModeViewModel(
            repositoryProvider: FailingRepositoryProvider(
                error: .invalidBookmark
            )
        )

        await viewModel.load()

        XCTAssertTrue(viewModel.requiresRepositorySelection)
        XCTAssertEqual(
            viewModel.errorMessage,
            RepositoryError.invalidBookmark.errorDescription
        )
    }

    func test_nonAccessFailureOffersRetryInsteadOfRepositorySelection() async {
        let viewModel = CodeModeViewModel(
            repositoryProvider: FailingRepositoryProvider(
                error: .notGitRepository
            )
        )

        await viewModel.load()

        XCTAssertFalse(viewModel.requiresRepositorySelection)
        XCTAssertEqual(
            viewModel.errorMessage,
            RepositoryError.notGitRepository.errorDescription
        )
    }

    func test_selectFileExposesSafeContentAndAddsItToContext() async {
        let file = RepositoryFile(path: "Sources/App.swift")
        let fileContent = RepositoryFileContent(
            file: file,
            content: "let token = [REDACTED]",
            wasTruncated: false,
            containsRedactions: true
        )
        let repositoryClient = RepositoryClientStub(
            repositoryFiles: [file],
            fileContents: [file.path: fileContent]
        )
        let viewModel = CodeModeViewModel(
            repositoryProvider: RepositoryProviderStub(
                client: repositoryClient
            )
        )

        await viewModel.load()
        await viewModel.select(file)

        XCTAssertEqual(viewModel.repositoryFiles, [file])
        XCTAssertEqual(viewModel.selectedFileContent, fileContent)
        XCTAssertNil(viewModel.selectedChange)
        XCTAssertTrue(
            viewModel.contextMessages()[0].content.contains(
                "let token = [REDACTED]"
            )
        )
        XCTAssertTrue(
            viewModel.contextMessages()[0].content.contains(
                "Hassas değerler SDK tarafından maskelendi"
            )
        )
    }

    func test_selectingChangeClearsSelectedRepositoryFile() async {
        let file = RepositoryFile(path: "Sources/App.swift")
        let change = RepositoryChange(
            path: "Sources/Other.swift",
            status: .modified,
            area: .unstaged
        )
        let repositoryClient = RepositoryClientStub(
            changes: [change],
            diffs: [change.id: "+change"],
            repositoryFiles: [file],
            fileContents: [
                file.path: RepositoryFileContent(
                    file: file,
                    content: "content",
                    wasTruncated: false,
                    containsRedactions: false
                )
            ]
        )
        let viewModel = CodeModeViewModel(
            repositoryProvider: RepositoryProviderStub(
                client: repositoryClient
            )
        )

        await viewModel.load()
        await viewModel.select(file)
        await viewModel.select(change)

        XCTAssertNil(viewModel.selectedFileContent)
        XCTAssertEqual(viewModel.selectedChange, change)
        XCTAssertEqual(viewModel.selectedDiff, "+change")
    }

    func test_editProposalRequiresApprovalAndWritesSelectedFile() async {
        let file = RepositoryFile(path: "Sources/App.swift")
        let client = RepositoryClientStub(
            repositoryFiles: [file],
            fileContents: [
                file.path: RepositoryFileContent(
                    file: file,
                    content: "let value = 1",
                    wasTruncated: false,
                    containsRedactions: false
                )
            ]
        )
        let viewModel = CodeModeViewModel(
            repositoryProvider: RepositoryProviderStub(client: client)
        )

        await viewModel.load()
        await viewModel.select(file)
        viewModel.prepareEditProposal(
            from: "Öneri:\n```swift\nlet value = 2\n```"
        )

        XCTAssertEqual(
            viewModel.editProposal?.proposedContent,
            "let value = 2"
        )
        XCTAssertTrue(
            viewModel.editProposal?.preview.contains("+let value = 2")
                == true
        )
        let contentBeforeApproval = await client.writtenContent()
        XCTAssertNil(contentBeforeApproval)

        await viewModel.applyEditProposal()

        let writtenPath = await client.writtenPath()
        let writtenContent = await client.writtenContent()
        XCTAssertEqual(writtenPath, file.path)
        XCTAssertEqual(writtenContent, "let value = 2")
        XCTAssertNil(viewModel.editProposal)
    }
}

private actor RepositoryProviderStub: RepositoryProvider {
    private let client: any RepositoryClient
    private(set) var resolutionCount = 0
    private(set) var resolvedProjectID: UUID?
    private(set) var resolvedConversationID: UUID?

    init(client: any RepositoryClient) {
        self.client = client
    }

    func activeRepositoryClient() async throws -> any RepositoryClient {
        resolutionCount += 1
        return client
    }

    func repositoryClient(
        forProject projectID: UUID
    ) async throws -> any RepositoryClient {
        resolutionCount += 1
        resolvedProjectID = projectID
        return client
    }

    func repositoryClient(
        for conversationID: UUID
    ) async throws -> any RepositoryClient {
        resolutionCount += 1
        resolvedConversationID = conversationID
        return client
    }
}

private actor FailingRepositoryProvider: RepositoryProvider {
    let error: RepositoryError

    init(error: RepositoryError) {
        self.error = error
    }

    func activeRepositoryClient() async throws -> any RepositoryClient {
        throw error
    }
}

private actor RepositoryClientStub: RepositoryClient, RepositoryFileWriting {
    nonisolated let repository = RepositoryDescriptor(
        displayName: "AIChat",
        rootURL: URL(fileURLWithPath: "/tmp/AIChat")
    )

    private var statusChanges: [[RepositoryChange]]
    private let diffs: [String: String]
    private let repositoryFiles: [RepositoryFile]
    private let fileContents: [String: RepositoryFileContent]
    private var capturedWrittenPath: String?
    private var capturedWrittenContent: String?

    init(
        changes: [RepositoryChange] = [],
        diffs: [String: String] = [:],
        repositoryFiles: [RepositoryFile] = [],
        fileContents: [String: RepositoryFileContent] = [:]
    ) {
        statusChanges = [changes]
        self.diffs = diffs
        self.repositoryFiles = repositoryFiles
        self.fileContents = fileContents
    }

    init(
        statusChanges: [[RepositoryChange]],
        diffs: [String: String] = [:]
    ) {
        self.statusChanges = statusChanges
        self.diffs = diffs
        repositoryFiles = []
        fileContents = [:]
    }

    func status() async throws -> RepositoryStatus {
        let changes = statusChanges.isEmpty ? [] : statusChanges.removeFirst()
        return RepositoryStatus(
            repository: repository,
            branchName: "sdk-v2",
            headRevision: "abc123",
            changes: changes
        )
    }

    func diff(for change: RepositoryChange) async throws -> String {
        diffs[change.id] ?? ""
    }

    func files() async throws -> [RepositoryFile] {
        repositoryFiles
    }

    func readFile(
        at path: String,
        maximumByteCount: Int
    ) async throws -> RepositoryFileContent {
        guard let content = fileContents[path] else {
            throw RepositoryError.fileNotFound
        }
        return content
    }

    func writeFile(
        at path: String,
        content: String,
        maximumByteCount: Int
    ) async throws {
        capturedWrittenPath = path
        capturedWrittenContent = content
    }

    func writtenPath() -> String? {
        capturedWrittenPath
    }

    func writtenContent() -> String? {
        capturedWrittenContent
    }
}

@MainActor
private final class CodeModeProviderRegistryStub: AIProviderRegistry {
    let providers: [any AIProvider] = []

    func reload() {}

    func provider(withID id: String) -> (any AIProvider)? {
        nil
    }
}
