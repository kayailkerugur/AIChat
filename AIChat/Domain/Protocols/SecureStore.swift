//
//  SecureStore.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//
//  Abstraction over secure key-value storage. The real implementation
//  is Keychain-backed; tests and previews use an in-memory fake.
//  Every sensitive value in the app (provider API keys, OAuth
//  access/refresh tokens) goes through this and
//  ONLY this — never UserDefaults, Core Data, plist or logs (spec §6.2).
//

import Foundation

/// Well-known, compile-time keys. Raw values are the Keychain account
/// names — stable strings, do not rename casually.
enum SecureStoreKey: String, CaseIterable {
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
    func read(key: String) throws -> String?
    /// Creates or overwrites the value.
    func save(_ value: String, forKey key: String) throws
    /// Deleting a non-existent key is not an error.
    func delete(key: String) throws
}

// MARK: - Typed convenience for well-known keys

extension SecureStore {
    func read(_ key: SecureStoreKey) throws -> String? {
        try read(key: key.rawValue)
    }

    func save(_ value: String, for key: SecureStoreKey) throws {
        try save(value, forKey: key.rawValue)
    }

    func delete(_ key: SecureStoreKey) throws {
        try delete(key: key.rawValue)
    }
}
