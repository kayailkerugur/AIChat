import XCTest
import AIChatSDK

@MainActor
final class AIChatClientTests: XCTestCase {
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
