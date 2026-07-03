//
//  AppDependencies.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//
//  App/
//
//  Composition root. This is the ONLY place in the app where concrete
//  implementations (Mock…, InMemory…, OAuth…, CoreData…) are instantiated.
//  Everything else receives dependencies as protocols.
//
//  UPDATED (sidebar step): registers ConversationRepository and
//  MessageRepository. One InMemoryChatRepository instance backs both —
//  in Days 11–15 a CoreData-backed pair replaces it right here.
//

import Foundation

@MainActor
final class AppDependencies {

    let authService: AuthService
    let aiProvider: AIProvider
    let conversationRepository: ConversationRepository
    let messageRepository: MessageRepository

    init(
        authService: AuthService,
        aiProvider: AIProvider,
        conversationRepository: ConversationRepository,
        messageRepository: MessageRepository
    ) {
        self.authService = authService
        self.aiProvider = aiProvider
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
    }

    /// Default configuration used by the running app.
    static func makeDefault() -> AppDependencies {
        let chatStore = InMemoryChatRepository()
        return AppDependencies(
            authService: MockAuthService(),
            aiProvider: MockAIProvider(),
            conversationRepository: chatStore,
            messageRepository: chatStore
        )
    }

    /// Handy for SwiftUI previews & UI experiments:
    /// e.g. `.makePreview(auth: .init(loginFailure: .network))`
    static func makePreview(
        auth authBehavior: MockAuthService.Behavior = .init(latency: .zero),
        ai aiBehavior: MockAIProvider.Behavior = .init(chunkDelay: .milliseconds(40))
    ) -> AppDependencies {
        let chatStore = InMemoryChatRepository()
        return AppDependencies(
            authService: MockAuthService(behavior: authBehavior),
            aiProvider: MockAIProvider(behavior: aiBehavior),
            conversationRepository: chatStore,
            messageRepository: chatStore
        )
    }
}
