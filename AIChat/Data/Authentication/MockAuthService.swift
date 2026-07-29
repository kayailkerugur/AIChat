//
//  MockAuthService.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//

import Foundation

final class MockAuthService: AuthService {

    // MARK: - Configuration (tweak these to exercise different UI states)

    struct Behavior {
        /// Artificial delay so loading indicators are visible.
        var latency: Duration = .seconds(1)

        /// When set, `login()` throws this error instead of succeeding.
        var loginFailure: AuthError? = nil

        /// When set, `restoreSession()` throws this error.
        var restoreFailure: AuthError? = nil

        /// Simulates "remember me across launches" using a harmless flag.
        var simulatesPersistedSession: Bool = true

        /// Starts with a fake authenticated session for previews and UI tests.
        var startsAuthenticated: Bool = false
    }

    var behavior: Behavior

    // MARK: - AuthService

    private(set) var currentSession: AuthSession?

    var sessionUpdates: AsyncStream<AuthSession?> {
        AsyncStream { continuation in
            self.continuations.append(continuation)
            continuation.yield(self.currentSession)
        }
    }

    private var continuations: [AsyncStream<AuthSession?>.Continuation] = []
    private let persistedFlagKey = "mock.auth.hasSession" // non-sensitive bool only

    init(behavior: Behavior = Behavior()) {
        self.behavior = behavior
        if behavior.startsAuthenticated {
            currentSession = Self.makeFakeSession()
        }
    }

    @discardableResult
    func restoreSession() async throws -> AuthSession {
        try await Task.sleep(for: behavior.latency)

        if let failure = behavior.restoreFailure {
            throw failure
        }

        if let currentSession {
            return currentSession
        }

        let hasPersisted = behavior.simulatesPersistedSession
            && UserDefaults.standard.bool(forKey: persistedFlagKey)

        guard hasPersisted else {
            throw AuthError.noStoredSession
        }

        let session = Self.makeFakeSession()
        update(session)
        return session
    }

    @discardableResult
    func login() async throws -> AuthSession {
        try await Task.sleep(for: behavior.latency)

        if let failure = behavior.loginFailure {
            throw failure
        }

        let session = Self.makeFakeSession()
        if behavior.simulatesPersistedSession {
            UserDefaults.standard.set(true, forKey: persistedFlagKey)
        }
        update(session)
        return session
    }

    func logout() async {
        UserDefaults.standard.removeObject(forKey: persistedFlagKey)
        update(nil)
    }

    // MARK: - Helpers
    private func update(_ session: AuthSession?) {
        currentSession = session
        for continuation in continuations {
            continuation.yield(session)
        }
    }

    private static func makeFakeSession() -> AuthSession {
        AuthSession(
            userID: "mock-user-1",
            displayName: "Test Kullanıcısı",
            email: "test@example.com",
            providerID: "mock",
            expiresAt: Date().addingTimeInterval(60 * 60) // 1 hour
        )
    }
}
