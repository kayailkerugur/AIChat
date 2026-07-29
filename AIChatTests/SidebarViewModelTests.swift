import AIChatSDK
import XCTest
@testable import AIChat

@MainActor
final class SidebarViewModelTests: XCTestCase {
    func test_moveConversationRemovesItFromSelectedProject() async throws {
        let sourceProjectID = UUID()
        let destinationProjectID = UUID()
        let conversation = Conversation(
            title: "Move me",
            providerID: "mock",
            modelID: "mock-model",
            projectID: sourceProjectID
        )
        let repository = InMemoryChatRepository()
        try await repository.create(conversation)
        let viewModel = makeViewModel(
            repository: repository,
            projectID: sourceProjectID
        )
        var movedConversationID: UUID?
        viewModel.onConversationMoved = {
            movedConversationID = $0
        }

        await viewModel.refresh()
        viewModel.selectedConversationID = conversation.id
        await viewModel.move(
            conversationID: conversation.id,
            toProject: destinationProjectID
        )

        XCTAssertTrue(viewModel.conversations.isEmpty)
        XCTAssertNil(viewModel.selectedConversationID)
        XCTAssertEqual(movedConversationID, conversation.id)
        let destinationConversations = try await repository.conversations(
            inProject: destinationProjectID
        )
        XCTAssertEqual(destinationConversations.map(\.id), [conversation.id])
    }

    func test_codeModeRequiresProjectBeforeCreatingConversation() async {
        let repository = InMemoryChatRepository()
        let viewModel = makeViewModel(
            repository: repository,
            projectID: nil
        )

        await viewModel.createConversation()

        XCTAssertEqual(
            viewModel.errorMessage,
            "Yeni sohbet için önce bir proje seçin."
        )
    }

    func test_standardModeCreatesConversationInsideSelectedFolder() async {
        let folderID = UUID()
        let repository = InMemoryChatRepository()
        let viewModel = SidebarViewModel(
            conversationRepository: repository,
            usesProjects: true,
            defaultModel: {
                AIModel(
                    id: "mock-model",
                    displayName: "Mock",
                    providerID: "mock"
                )
            }
        )
        viewModel.selectedProjectID = folderID

        await viewModel.createConversation()

        XCTAssertEqual(viewModel.conversations.count, 1)
        XCTAssertEqual(viewModel.conversations.first?.projectID, folderID)
    }

    func test_standardModeAllowsFolderlessConversation() async {
        let repository = InMemoryChatRepository()
        let viewModel = SidebarViewModel(
            conversationRepository: repository,
            usesProjects: true,
            defaultModel: {
                AIModel(
                    id: "mock-model",
                    displayName: "Mock",
                    providerID: "mock"
                )
            }
        )

        await viewModel.createConversation()

        XCTAssertEqual(viewModel.conversations.count, 1)
        XCTAssertNil(viewModel.conversations.first?.projectID)
    }

    private func makeViewModel(
        repository: InMemoryChatRepository,
        projectID: UUID?
    ) -> SidebarViewModel {
        let viewModel = SidebarViewModel(
            conversationRepository: repository,
            usesProjects: true,
            requiresProjectForNewConversation: true,
            defaultModel: {
                AIModel(
                    id: "mock-model",
                    displayName: "Mock",
                    providerID: "mock"
                )
            }
        )
        viewModel.selectedProjectID = projectID
        return viewModel
    }
}
