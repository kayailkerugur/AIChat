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
    private let projectRepository: (any ProjectRepository)?
    private let repositoryProvider: (any RepositoryProvider)?

    public init(
        configuration: AIChatConfiguration = .init(),
        providerRegistry: any AIProviderRegistry,
        conversationRepository: any ConversationRepository,
        messageRepository: any MessageRepository,
        projectRepository: (any ProjectRepository)? = nil,
        repositoryProvider: (any RepositoryProvider)? = nil
    ) {
        self.configuration = configuration
        self.providerRegistry = providerRegistry
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
        self.projectRepository = projectRepository
        self.repositoryProvider = repositoryProvider
    }

    public func conversations() async throws -> [Conversation] {
        try await conversationRepository.conversations()
    }

    public func conversations(
        inProject projectID: UUID?
    ) async throws -> [Conversation] {
        try await conversationRepository.conversations(inProject: projectID)
    }

    public func searchConversations(matching query: String) async throws -> [Conversation] {
        try await conversationRepository.searchConversations(matching: query)
    }

    @discardableResult
    public func createConversation(
        providerID: String,
        modelID: String,
        projectID: UUID? = nil,
        title: String? = nil
    ) async throws -> Conversation {
        guard providerRegistry.provider(withID: providerID) != nil else {
            throw AIChatError.modelUnavailable
        }

        let conversation = Conversation(
            title: title ?? configuration.defaultConversationTitle,
            providerID: providerID,
            modelID: modelID,
            projectID: projectID
        )
        try await conversationRepository.create(conversation)
        return conversation
    }

    public func deleteConversation(id: UUID) async throws {
        try await conversationRepository.delete(conversationID: id)
    }

    public func moveConversation(
        id: UUID,
        toProject projectID: UUID?
    ) async throws {
        try await conversationRepository.move(
            conversationID: id,
            toProject: projectID
        )
    }

    public func projects() async throws -> [AIChatProject] {
        try await requiredProjectRepository().projects()
    }

    public func project(id: UUID) async throws -> AIChatProject? {
        try await requiredProjectRepository().project(id: id)
    }

    @discardableResult
    public func createProject(name: String) async throws -> AIChatProject {
        let project = AIChatProject(name: name)
        try await requiredProjectRepository().create(project)
        return project
    }

    public func renameProject(id: UUID, to name: String) async throws {
        try await requiredProjectRepository().rename(projectID: id, to: name)
    }

    public func deleteProject(id: UUID) async throws {
        try await requiredProjectRepository().delete(projectID: id)
    }

    private func requiredProjectRepository() throws -> any ProjectRepository {
        guard let projectRepository else {
            throw AIChatClientConfigurationError.projectRepositoryRequired
        }
        return projectRepository
    }

    /// Creates the repository state model used by code-mode presentation.
    /// Standard mode never resolves or invokes a repository provider.
    public func makeCodeModeViewModel() throws -> CodeModeViewModel {
        try makeCodeModeViewModel(projectID: nil, conversationID: nil)
    }

    /// Creates repository state scoped to the conversation's project.
    /// Conversations created before project support retain their legacy
    /// conversation-scoped repository resolution.
    public func makeCodeModeViewModel(
        for conversation: Conversation
    ) throws -> CodeModeViewModel {
        try makeCodeModeViewModel(
            projectID: conversation.projectID,
            conversationID: conversation.id
        )
    }

    /// Creates repository state for a project management screen without
    /// coupling it to a particular conversation.
    public func makeCodeModeViewModel(
        for project: AIChatProject
    ) throws -> CodeModeViewModel {
        try makeCodeModeViewModel(
            projectID: project.id,
            conversationID: nil
        )
    }

    private func makeCodeModeViewModel(
        projectID: UUID?,
        conversationID: UUID?
    ) throws -> CodeModeViewModel {
        guard configuration.mode == .code else {
            throw AIChatClientConfigurationError.codeModeRequired
        }
        guard let repositoryProvider else {
            throw AIChatClientConfigurationError.repositoryProviderRequired
        }
        return CodeModeViewModel(
            repositoryProvider: repositoryProvider,
            projectID: projectID,
            conversationID: conversationID,
            contextCharacterLimit: configuration.codeContextCharacterLimit,
            fileByteLimit: configuration.codeFileByteLimit
        )
    }

    public func makeChatViewModel(
        for conversation: Conversation,
        contextProvider: (any ChatContextProvider)? = nil,
        onConversationMutated: @escaping @MainActor () -> Void = {}
    ) throws -> ChatViewModel {
        guard let provider = providerRegistry.resolvedProvider(
            forID: conversation.providerID
        ) else {
            throw AIChatError.modelUnavailable
        }

        return ChatViewModel(
            conversation: conversation,
            aiProvider: provider,
            messageRepository: messageRepository,
            conversationRepository: conversationRepository,
            defaultConversationTitle: configuration.defaultConversationTitle,
            contextProvider: contextProvider,
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

    /// Creates the mode-aware SDK interface selected by the host
    /// application's configuration.
    public func makeSDKView(
        for conversation: Conversation,
        theme: AIChatTheme? = nil,
        branding: AIChatBranding? = nil,
        onSelectRepository: (() -> Void)? = nil,
        onConversationMutated: @escaping @MainActor () -> Void = {}
    ) throws -> AIChatSDKView {
        try AIChatSDKView(
            client: self,
            conversation: conversation,
            theme: theme,
            branding: branding,
            onSelectRepository: onSelectRepository,
            onConversationMutated: onConversationMutated
        )
    }
}
