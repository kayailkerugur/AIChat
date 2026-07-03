//
//  AppDependencies.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//

import Foundation

@MainActor
final class AppDependencies {

    let authService: AuthService
    // Later phases will add:
    // let conversationRepository: ConversationRepository
    // let aiProvider: AIProvider
    // let tokenStore: TokenStore

    init(authService: AuthService) {
        self.authService = authService
    }

    /// Default configuration used by the running app.
    static func makeDefault() -> AppDependencies {
        AppDependencies(
            authService: MockAuthService()
        )
    }

    /// Handy for SwiftUI previews & UI experiments:
    /// e.g. `.makePreview(auth: .init(loginFailure: .network))`
    static func makePreview(
        auth behavior: MockAuthService.Behavior = .init(latency: .zero)
    ) -> AppDependencies {
        AppDependencies(
            authService: MockAuthService(behavior: behavior)
        )
    }
}
