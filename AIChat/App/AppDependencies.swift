//
//  AppDependencies.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//
//  Composition root. This is the ONLY place in the app where concrete
//  implementations (Mock…, InMemory…, CoreData…, OAuth…) are instantiated.
//  Everything else receives dependencies as protocols.
//
//  UPDATED (Core Data step): the running app now persists through
//  CoreDataChatRepository; previews and tests keep InMemoryChatRepository.
//  Exactly one line of difference between the two factories — the
//  swap the architecture was designed for.
//

import Foundation
import os

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
            aiProvider: MockAIProvider(),
            conversationRepository: chatStore,
            messageRepository: chatStore
        )
    }

    /// Handy for SwiftUI previews & UI experiments — stays in-memory,
    /// no disk writes from previews.
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
