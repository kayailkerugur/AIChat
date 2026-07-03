//
//  RootViewModel.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class RootViewModel {

    enum State: Equatable {
        /// App just launched; we are checking Keychain / stored session.
        case checkingSession
        /// No valid session → show Login.
        case loggedOut
        /// Valid session → show the main window (sidebar + chat).
        case loggedIn(AuthSession)
    }

    private(set) var state: State = .checkingSession

    private let authService: AuthService
    private var observationTask: Task<Void, Never>?

    init(authService: AuthService) {
        self.authService = authService
    }

    /// Call once from the root view's `.task`.
    func start() async {
        // 1. Subscribe to future session changes (login/logout/expiry).
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await session in self.authService.sessionUpdates {
                // Ignore stream values while the initial restore is running,
                // restoreSession() itself resolves the first state.
                guard self.state != .checkingSession else { continue }
                self.apply(session)
            }
        }

        // 2. Resolve the initial state.
        do {
            let session = try await authService.restoreSession()
            state = .loggedIn(session)
        } catch {
            // noStoredSession / sessionExpired / anything else → Login.
            // Login screen can show a message for `sessionExpired` later if desired.
            state = .loggedOut
        }
    }

    private func apply(_ session: AuthSession?) {
        if let session {
            state = .loggedIn(session)
        } else {
            state = .loggedOut
        }
    }
}
