import XCTest
import AIChatSDK

@MainActor
final class AIChatClientTests: XCTestCase {
    func test_projectLifecycleUsesInjectedProjectRepository() async throws {
        let chatStore = InMemoryChatRepository()
        let projectStore = InMemoryProjectRepository()
        let client = AIChatClient(
            providerRegistry: TestProviderRegistry(providers: []),
            conversationRepository: chatStore,
            messageRepository: chatStore,
            projectRepository: projectStore
        )

        let project = try await client.createProject(name: "AIChat")
        let createdProject = try await client.project(id: project.id)
        XCTAssertEqual(createdProject, project)

        try await client.renameProject(id: project.id, to: "SDK")
        let renamedProject = try await client.project(id: project.id)
        XCTAssertEqual(renamedProject?.name, "SDK")

        try await client.deleteProject(id: project.id)
        let projects = try await client.projects()
        XCTAssertTrue(projects.isEmpty)
    }

    func test_createConversationPersistsConfiguredDefaultTitle() async throws {
        let store = InMemoryChatRepository()
        let provider = MockAIProvider()
        let client = AIChatClient(
            configuration: .init(defaultConversationTitle: "Untitled"),
            providerRegistry: TestProviderRegistry(providers: [provider]),
            conversationRepository: store,
            messageRepository: store
        )

        let conversation = try await client.createConversation(
            providerID: provider.id,
            modelID: provider.supportedModels[0].id
        )

        let conversations = try await client.conversations()

        XCTAssertEqual(conversation.title, "Untitled")
        XCTAssertEqual(conversations, [conversation])
    }

    func test_clientExposesDeveloperSelectedMode() {
        let store = InMemoryChatRepository()
        let client = AIChatClient(
            configuration: .init(mode: .code),
            providerRegistry: TestProviderRegistry(providers: []),
            conversationRepository: store,
            messageRepository: store
        )

        XCTAssertEqual(client.configuration.mode, .code)
    }

    func test_unknownProviderIsRejectedBeforePersistence() async throws {
        let store = InMemoryChatRepository()
        let client = AIChatClient(
            providerRegistry: TestProviderRegistry(providers: []),
            conversationRepository: store,
            messageRepository: store
        )

        do {
            _ = try await client.createConversation(
                providerID: "missing",
                modelID: "missing-model"
            )
            XCTFail("Expected modelUnavailable")
        } catch let error as AIChatError {
            XCTAssertEqual(error, .modelUnavailable)
        }

        let conversations = try await client.conversations()
        XCTAssertTrue(conversations.isEmpty)
    }

    func test_makeChatViewModelResolvesInjectedProvider() throws {
        let store = InMemoryChatRepository()
        let provider = MockAIProvider()
        let client = AIChatClient(
            providerRegistry: TestProviderRegistry(providers: [provider]),
            conversationRepository: store,
            messageRepository: store
        )
        let conversation = Conversation(
            title: "Conversation",
            providerID: provider.id,
            modelID: provider.supportedModels[0].id
        )

        let viewModel = try client.makeChatViewModel(for: conversation)

        XCTAssertEqual(viewModel.conversation, conversation)
    }

    func test_makeSDKViewInStandardModeDoesNotRequireRepositoryProvider() throws {
        let store = InMemoryChatRepository()
        let provider = MockAIProvider()
        let client = AIChatClient(
            configuration: .init(mode: .standard),
            providerRegistry: TestProviderRegistry(providers: [provider]),
            conversationRepository: store,
            messageRepository: store
        )
        let conversation = Conversation(
            title: "Conversation",
            providerID: provider.id,
            modelID: provider.supportedModels[0].id
        )

        XCTAssertNoThrow(try client.makeSDKView(for: conversation))
    }

    func test_makeSDKViewInCodeModeRequiresRepositoryProvider() {
        let store = InMemoryChatRepository()
        let provider = MockAIProvider()
        let client = AIChatClient(
            configuration: .init(mode: .code),
            providerRegistry: TestProviderRegistry(providers: [provider]),
            conversationRepository: store,
            messageRepository: store
        )
        let conversation = Conversation(
            title: "Conversation",
            providerID: provider.id,
            modelID: provider.supportedModels[0].id
        )

        XCTAssertThrowsError(try client.makeSDKView(for: conversation)) { error in
            XCTAssertEqual(
                error as? AIChatClientConfigurationError,
                .repositoryProviderRequired
            )
        }
    }

    func test_makeSDKViewAcceptsHostRepositorySelectionAction() throws {
        let store = InMemoryChatRepository()
        let provider = MockAIProvider()
        let client = AIChatClient(
            configuration: .init(mode: .code),
            providerRegistry: TestProviderRegistry(providers: [provider]),
            conversationRepository: store,
            messageRepository: store,
            repositoryProvider: SDKViewRepositoryProviderStub()
        )
        let conversation = Conversation(
            title: "Conversation",
            providerID: provider.id,
            modelID: provider.supportedModels[0].id
        )

        XCTAssertNoThrow(
            try client.makeSDKView(
                for: conversation,
                onSelectRepository: {}
            )
        )
    }
}

private actor SDKViewRepositoryProviderStub: RepositoryProvider {
    func activeRepositoryClient() async throws -> any RepositoryClient {
        throw RepositoryError.invalidBookmark
    }
}

@MainActor
private final class TestProviderRegistry: AIProviderRegistry {
    let providers: [any AIProvider]

    init(providers: [any AIProvider]) {
        self.providers = providers
    }

    func reload() {}

    func provider(withID id: String) -> (any AIProvider)? {
        providers.first { $0.id == id }
    }
}
