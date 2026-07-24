import Foundation

/// Main entry point for composing reusable AI chat flows.
///
/// The host application owns authentication, navigation and window lifecycle.
/// SDK dependencies are supplied through protocols so the client does not
/// depend on an application composition root.
@MainActor
public final class AIChatClient {
    public let configuration: AIChatConfiguration

    private let providerRegistry: any AIProviderRegistry
    private let conversationRepository: any ConversationRepository
    private let messageRepository: any MessageRepository

    public init(
        configuration: AIChatConfiguration = .init(),
        providerRegistry: any AIProviderRegistry,
        conversationRepository: any ConversationRepository,
        messageRepository: any MessageRepository
    ) {
        self.configuration = configuration
        self.providerRegistry = providerRegistry
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
    }

    public func conversations() async throws -> [Conversation] {
        try await conversationRepository.conversations()
    }

    public func searchConversations(matching query: String) async throws -> [Conversation] {
        try await conversationRepository.searchConversations(matching: query)
    }

    @discardableResult
    public func createConversation(
        providerID: String,
        modelID: String,
        title: String? = nil
    ) async throws -> Conversation {
        guard providerRegistry.provider(withID: providerID) != nil else {
            throw AIChatError.modelUnavailable
        }

        let conversation = Conversation(
            title: title ?? configuration.defaultConversationTitle,
            providerID: providerID,
            modelID: modelID
        )
        try await conversationRepository.create(conversation)
        return conversation
    }

    public func deleteConversation(id: UUID) async throws {
        try await conversationRepository.delete(conversationID: id)
    }

    public func makeChatViewModel(
        for conversation: Conversation,
        onConversationMutated: @escaping @MainActor () -> Void = {}
    ) throws -> ChatViewModel {
        guard let provider = providerRegistry.provider(withID: conversation.providerID) else {
            throw AIChatError.modelUnavailable
        }

        return ChatViewModel(
            conversation: conversation,
            aiProvider: provider,
            messageRepository: messageRepository,
            conversationRepository: conversationRepository,
            defaultConversationTitle: configuration.defaultConversationTitle,
            onConversationMutated: onConversationMutated
        )
    }

    public func makeChatView(
        for conversation: Conversation,
        theme: AIChatTheme? = nil,
        branding: AIChatBranding? = nil,
        onConversationMutated: @escaping @MainActor () -> Void = {}
    ) throws -> AIChatView {
        AIChatView(
            viewModel: try makeChatViewModel(
                for: conversation,
                onConversationMutated: onConversationMutated
            ),
            theme: theme,
            branding: branding
        )
    }
}
