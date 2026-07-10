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
import os

@MainActor
final class AppDependencies {

    let authService: AuthService
    let aiProviders: AIProviderRegistry
    let conversationRepository: ConversationRepository
    let messageRepository: MessageRepository
    let secureStore: SecureStore
    let providerConfigStore: ProviderConfigStore
    let environment: AppEnvironment

    init(
        authService: AuthService,
        aiProviders: AIProviderRegistry,
        conversationRepository: ConversationRepository,
        messageRepository: MessageRepository,
        secureStore: SecureStore,
        providerConfigStore: ProviderConfigStore,
        environment: AppEnvironment
    ) {
        self.authService = authService
        self.aiProviders = aiProviders
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
        self.secureStore = secureStore
        self.providerConfigStore = providerConfigStore
        self.environment = environment
    }

    /// Default configuration used by the running app.
    static func makeDefault() -> AppDependencies {
        let environment = AppEnvironment.production
        let secureStore = KeychainStore()
        let providerConfigStore = UserDefaultsProviderConfigStore()
        let chatStore = CoreDataChatRepository(persistence: .shared)

        let aiProviders = ConfigBackedAIProviderRegistry(
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
            secureStore: secureStore,
            providerConfigStore: providerConfigStore,
            environment: environment
        )
    }

    /// Handy for SwiftUI previews & UI experiments — stays fully offline.
    static func makePreview(
        auth authBehavior: MockAuthService.Behavior = .init(latency: .zero),
        ai aiBehavior: MockAIProvider.Behavior = .init(chunkDelay: .milliseconds(40))
    ) -> AppDependencies {
        let secureStore = InMemorySecureStore()
        let providerConfigStore = UserDefaultsProviderConfigStore(
            defaults: UserDefaults(suiteName: "AIChat.preview.providers")!
        )
        let chatStore = InMemoryChatRepository()

        let mockProvider = MockAIProvider(behavior: aiBehavior)
        let aiProviders = StaticAIProviderRegistry(providers: [
            mockProvider
        ])

        return AppDependencies(
            authService: MockAuthService(behavior: authBehavior),
            aiProviders: aiProviders,
            conversationRepository: chatStore,
            messageRepository: chatStore,
            secureStore: secureStore,
            providerConfigStore: providerConfigStore,
            environment: .production
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
