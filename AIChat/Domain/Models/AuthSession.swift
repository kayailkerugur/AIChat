//
//  AuthSession.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//
//  Domain/Models
//
//  Represents an authenticated user session.
//  IMPORTANT: This model intentionally does NOT contain access/refresh tokens.
//  Tokens live behind TokenStore (Keychain) and never travel through
//  the Presentation layer.
//

import Foundation

struct AuthSession: Equatable, Identifiable {
    /// Stable identifier of the authenticated user (subject claim, provider user id, etc.)
    let userID: String

    /// Display name shown in Settings / profile UI. Optional because
    /// not every provider returns it.
    let displayName: String?

    /// Optional e-mail for the profile section.
    let email: String?

    /// The OAuth provider this session was created with (e.g. "google", "github", "mock").
    let providerID: String

    /// When the current access token expires. `nil` means unknown/not tracked.
    /// Used by the app to decide whether a silent refresh is needed.
    let expiresAt: Date?

    var id: String { userID }

    /// Convenience: is the session known to be expired right now?
    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date()
    }
}
