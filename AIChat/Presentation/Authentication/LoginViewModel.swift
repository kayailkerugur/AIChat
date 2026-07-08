//
//  LoginViewModel.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {

    private(set) var isLoggingIn = false
    private(set) var errorMessage: String?

    private let authService: AuthService
    private var loginTask: Task<Void, Never>?

    init(authService: AuthService, initialError: AuthError? = nil) {
        self.authService = authService
        // Restore failures (e.g. sessionExpired) surface here so the user
        // knows WHY they landed on the login screen. Benign reasons have
        // a nil errorDescription and show nothing.
        self.errorMessage = initialError?.errorDescription
    }

    func loginTapped() {
        guard !isLoggingIn else { return } // prevent double-fire
        errorMessage = nil
        isLoggingIn = true

        loginTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isLoggingIn = false }
            do {
                try await self.authService.login()
                // Success: RootViewModel reacts via sessionUpdates.
            } catch let error as AuthError {
                // User cancelling the OAuth sheet is not an error worth a banner.
                if error != .cancelledByUser {
                    self.errorMessage = error.errorDescription
                }
            } catch {
                self.errorMessage = AuthError.unknown(
                    debugDescription: String(describing: error)
                ).errorDescription
            }
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
