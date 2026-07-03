//
//  AuthService.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//
//  Domain/Protocols
//
//  The single contract the rest of the app knows about authentication.
//  Presentation depends on THIS, never on OAuthService/MockAuthService directly.
//  Swapping mock ↔ real OAuth happens only in AppDependencies.
//

import Foundation

protocol AuthService: AnyObject {
    /// The current session, if any. `nil` means logged out.
    var currentSession: AuthSession? { get }

    /// Emits the session every time it changes (login, restore, refresh, logout).
    /// The root coordinator observes this to switch between Login and Main.
    var sessionUpdates: AsyncStream<AuthSession?> { get }

    /// Attempts to restore a previously persisted session on app launch.
    /// - Returns: the restored session.
    /// - Throws: `AuthError.noStoredSession` when there is nothing to restore,
    ///           `AuthError.sessionExpired` when refresh failed.
    @discardableResult
    func restoreSession() async throws -> AuthSession

    /// Runs the interactive login flow (OAuth + PKCE in the real implementation).
    /// - Returns: the newly created session.
    @discardableResult
    func login() async throws -> AuthSession

    /// Clears tokens from secure storage and wipes the in-memory session.
    func logout() async
}
