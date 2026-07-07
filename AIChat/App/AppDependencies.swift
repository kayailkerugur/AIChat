//
//  AppDependencies.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//
//  Composition root. This is the ONLY place in the app where concrete
//  implementations are instantiated.
//
//  UPDATED (multi-provider step): a provider REGISTRY replaces the
//  single provider. The running app registers Gemini (default) and
//  Mock — adding a future provider is one line in makeDefault().
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
    let environment: AppEnvironment

    init(
        authService: AuthService,
        aiProviders: AIProviderRegistry,
        conversationRepository: ConversationRepository,
        messageRepository: MessageRepository,
        secureStore: SecureStore,
        environment: AppEnvironment
    ) {
        self.authService = authService
        self.aiProviders = aiProviders
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
        self.secureStore = secureStore
        self.environment = environment
    }

    /// Default configuration used by the running app.
    static func makeDefault() -> AppDependencies {
        let environment = AppEnvironment.production
        let secureStore = KeychainStore()
        let chatStore = CoreDataChatRepository(persistence: .shared)

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
            authService: MockAuthService(),
            aiProviders: DefaultAIProviderRegistry(providers: [
                // First provider = app-wide fallback.
                GeminiProvider(
                    configuration: environment.gemini,
                    secureStore: secureStore
                ),
                MockAIProvider(),
                // Future providers register here — one line each.
            ]),
            conversationRepository: chatStore,
            messageRepository: chatStore,
            secureStore: secureStore,
            environment: environment
        )
    }

    /// Handy for SwiftUI previews & UI experiments — stays fully offline.
    static func makePreview(
        auth authBehavior: MockAuthService.Behavior = .init(latency: .zero),
        ai aiBehavior: MockAIProvider.Behavior = .init(chunkDelay: .milliseconds(40))
    ) -> AppDependencies {
        let chatStore = InMemoryChatRepository()
        return AppDependencies(
            authService: MockAuthService(behavior: authBehavior),
            aiProviders: DefaultAIProviderRegistry(providers: [
                MockAIProvider(behavior: aiBehavior)
            ]),
            conversationRepository: chatStore,
            messageRepository: chatStore,
            secureStore: InMemorySecureStore(),
            environment: .production
        )
    }
}
