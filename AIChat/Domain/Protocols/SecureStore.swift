//
//  SecureStore.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//
//  Abstraction over secure key-value storage. The real implementation
//  is Keychain-backed; tests and previews use an in-memory fake.
//  Every sensitive value in the app (Gemini API key today, OAuth
//  access/refresh tokens in the next phase) goes through this and
//  ONLY this — never UserDefaults, Core Data, plist or logs (spec §6.2).
//

import Foundation

/// Namespaced identifiers for stored secrets. Raw values become the
/// Keychain account name — stable strings, do not rename casually.
enum SecureStoreKey: String, CaseIterable {
    case geminiAPIKey = "ai.gemini.api-key"
    case oauthAccessToken = "auth.google.access-token"
    case oauthRefreshToken = "auth.google.refresh-token"
    /// Access token expiry as a unix timestamp string — stored alongside
    /// the token so restore can decide between reuse and refresh.
    case oauthTokenExpiry = "auth.google.token-expiry"
}

enum SecureStoreError: Error, Equatable {
    /// Keychain returned an unexpected OSStatus.
    case unhandled(status: Int32)
    /// Stored bytes could not be decoded as UTF-8.
    case corruptedData
}

protocol SecureStore: AnyObject {
    /// Returns nil when no value exists for the key.
    func read(_ key: SecureStoreKey) throws -> String?
    /// Creates or overwrites the value.
    func save(_ value: String, for key: SecureStoreKey) throws
    /// Deleting a non-existent key is not an error.
    func delete(_ key: SecureStoreKey) throws
}
