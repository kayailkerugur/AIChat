import AIChatSDK
import XCTest
@testable import AIChat

@MainActor
final class ProjectWorkspaceViewModelTests: XCTestCase {
    func test_loadReturnsOnlySelectedProjectConversations() async throws {
        let projectID = UUID()
        let repository = InMemoryChatRepository()
        let included = Conversation(
            title: "Included",
            providerID: "mock",
            modelID: "mock",
            projectID: projectID
        )
        try await repository.create(included)
        try await repository.create(Conversation(
            title: "Other",
            providerID: "mock",
            modelID: "mock",
            projectID: UUID()
        ))
        let viewModel = ProjectWorkspaceViewModel(
            projectID: projectID,
            conversationRepository: repository,
            metadataStore: MemoryProjectMetadataStore()
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.conversations.map(\.id), [included.id])
    }

    func test_detectsTechnologiesAndContextFiles() {
        let viewModel = ProjectWorkspaceViewModel(
            projectID: UUID(),
            conversationRepository: InMemoryChatRepository(),
            metadataStore: MemoryProjectMetadataStore()
        )
        let files = [
            RepositoryFile(path: "Package.swift"),
            RepositoryFile(path: "README.md"),
            RepositoryFile(path: "Sources/App.swift")
        ]

        XCTAssertEqual(
            viewModel.technologies(from: files),
            ["Swift", "Swift Package"]
        )
        XCTAssertEqual(
            viewModel.contextFiles(from: files).map(\.path),
            ["Package.swift", "README.md"]
        )
    }

    func test_saveSummaryUsesProjectScopedMetadata() {
        let store = MemoryProjectMetadataStore()
        let projectID = UUID()
        let viewModel = ProjectWorkspaceViewModel(
            projectID: projectID,
            conversationRepository: InMemoryChatRepository(),
            metadataStore: store
        )
        viewModel.summary = "  SDK projesi  "

        viewModel.saveContext()

        XCTAssertEqual(
            store.metadata(for: projectID),
            ProjectWorkspaceMetadata(
                summary: "SDK projesi"
            )
        )
    }
}

@MainActor
private final class MemoryProjectMetadataStore:
    ProjectWorkspaceMetadataStoring
{
    private var values: [UUID: ProjectWorkspaceMetadata] = [:]

    func metadata(for projectID: UUID) -> ProjectWorkspaceMetadata {
        values[projectID] ?? ProjectWorkspaceMetadata()
    }

    func save(_ metadata: ProjectWorkspaceMetadata, for projectID: UUID) {
        values[projectID] = metadata
    }
}
