//
//  AppDependencies.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//
//  Composition root. This is the ONLY place in the app where concrete
//  implementations are instantiated.
//
//  The running app builds providers from user-managed ProviderConfig
//  records. Mock remains available for previews and tests.
//

import Foundation
import AIChatSDK
import os

@MainActor
final class AppDependencies {

    let authService: AuthService
    let aiProviders: AIProviderRegistry
    let conversationRepository: ConversationRepository
    let messageRepository: MessageRepository
    let projectRepository: ProjectRepository
    let secureStore: SecureStore
    let providerConfigurationService: AIProviderConfigurationService
    let environment: AppEnvironment
    let aiChatClient: AIChatClient
    let repositoryProvider: AppRepositoryProvider?

    init(
        authService: AuthService,
        aiProviders: AIProviderRegistry,
        conversationRepository: ConversationRepository,
        messageRepository: MessageRepository,
        projectRepository: ProjectRepository,
        secureStore: SecureStore,
        providerConfigurationService: AIProviderConfigurationService,
        environment: AppEnvironment,
        sdkConfiguration: AppSDKConfiguration = .current
    ) {
        self.authService = authService
        self.aiProviders = aiProviders
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
        self.projectRepository = projectRepository
        self.secureStore = secureStore
        self.providerConfigurationService = providerConfigurationService
        self.environment = environment
        let repositoryProvider = sdkConfiguration.mode == .code
            ? AppRepositoryProvider(configuration: sdkConfiguration)
            : nil
        self.repositoryProvider = repositoryProvider
        self.aiChatClient = AIChatClient(
            configuration: sdkConfiguration.sdkConfiguration,
            providerRegistry: aiProviders,
            conversationRepository: conversationRepository,
            messageRepository: messageRepository,
            projectRepository: projectRepository,
            repositoryProvider: repositoryProvider
        )
    }

    /// Default configuration used by the running app.
    static func makeDefault() -> AppDependencies {
        let environment = AppEnvironment.production
        let secureStore = KeychainStore(
            service: (Bundle.main.bundleIdentifier ?? "com.aichat.app") + ".secure"
        )
        let providerConfigStore = UserDefaultsProviderConfigStore()
        let attachmentFileStore = AttachmentFileStore.applicationSupport(
            appIdentifier: Bundle.main.bundleIdentifier ?? "AIChat"
        )
        let chatStore = CoreDataChatRepository(
            persistence: .shared,
            attachmentFileStore: attachmentFileStore
        )
        let projectStore = CoreDataProjectRepository(persistence: .shared)

        let aiProviders = ConfigBackedAIProviderRegistry(
            configStore: providerConfigStore,
            secureStore: secureStore
        )
        let providerConfigurationService = DefaultAIProviderConfigurationService(
            configStore: providerConfigStore,
            secureStore: secureStore
        )

        // Launch repair: any message left in a non-terminal state by a
        // crash/force-quit is moved to a safe, explainable state before
        // the UI ever loads it.
        Task {
            do {
                try await chatStore.repairInterruptedStreams()
            } catch {
                AppLogger.persistence.error(
                    "Launch repair failed: \(error.localizedDescription)"
                )
            }
        }

        return AppDependencies(
            authService: OAuthService(
                configuration: environment.googleOAuth,
                secureStore: secureStore
            ),
            aiProviders: aiProviders,
            conversationRepository: chatStore,
            messageRepository: chatStore,
            projectRepository: projectStore,
            secureStore: secureStore,
            providerConfigurationService: providerConfigurationService,
            environment: environment
        )
    }

    /// Handy for SwiftUI previews & UI experiments — stays fully offline.
    static func makePreview(
        auth authBehavior: MockAuthService.Behavior = .init(latency: .zero),
        ai aiBehavior: MockAIProvider.Behavior = .init(chunkDelay: .milliseconds(40)),
        sdkConfiguration: AppSDKConfiguration = .current,
        projects: [AIChatProject] = [],
        conversations: [Conversation] = []
    ) -> AppDependencies {
        let secureStore = InMemorySecureStore()
        let providerConfigStore = UserDefaultsProviderConfigStore(
            defaults: UserDefaults(suiteName: "AIChat.preview.providers")!
        )
        let chatStore = InMemoryChatRepository(
            conversations: conversations
        )
        let projectStore = InMemoryProjectRepository(projects: projects)

        let mockProvider = MockAIProvider(behavior: aiBehavior)
        let aiProviders = StaticAIProviderRegistry(providers: [
            mockProvider
        ])
        let providerConfigurationService = DefaultAIProviderConfigurationService(
            configStore: providerConfigStore,
            secureStore: secureStore
        )

        return AppDependencies(
            authService: MockAuthService(behavior: authBehavior),
            aiProviders: aiProviders,
            conversationRepository: chatStore,
            messageRepository: chatStore,
            projectRepository: projectStore,
            secureStore: secureStore,
            providerConfigurationService: providerConfigurationService,
            environment: .production,
            sdkConfiguration: sdkConfiguration
        )
    }

    /// Deterministic, offline dependency graph used only by UI test launches.
    static func makeForUITesting(
        mode: AIChatMode,
        repositoryURL: URL? = nil,
        repositoryError: RepositoryError? = nil
    ) -> AppDependencies {
        let primaryProjectID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000042"
        )!
        let secondaryProjectID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000043"
        )!
        let projects: [AIChatProject] = mode == .code
            ? [
                AIChatProject(
                    id: primaryProjectID,
                    name: "UI Test Project"
                ),
                AIChatProject(
                    id: secondaryProjectID,
                    name: "UI Test Project 2"
                )
            ]
            : []
        let conversations: [Conversation] = mode == .code
            ? [
                Conversation(
                    id: UUID(
                        uuidString:
                            "00000000-0000-0000-0000-000000000044"
                    )!,
                    title: "UI Test Conversation",
                    providerID: "mock",
                    modelID: "mock-model",
                    projectID: primaryProjectID
                )
            ]
            : []
        return makePreview(
            auth: .init(
                latency: .zero,
                simulatesPersistedSession: false,
                startsAuthenticated: true
            ),
            ai: .init(chunkDelay: .zero),
            sdkConfiguration: .init(
                mode: mode,
                repositoryURL: repositoryURL,
                repositoryError: repositoryError
            ),
            projects: projects,
            conversations: conversations
        )
    }
}

final class StaticAIProviderRegistry: AIProviderRegistry {

    let providers: [AIProvider]

    init(providers: [AIProvider]) {
        self.providers = providers
    }

    func reload() {}

    func provider(withID id: String) -> AIProvider? {
        providers.first { $0.id == id }
    }
}
