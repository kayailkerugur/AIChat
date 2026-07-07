//
//  KeychainStore.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//
//  Keychain Services implementation of SecureStore using
//  kSecClassGenericPassword items, namespaced by service name
//  (spec §6.2: "Keychain kayıtları servis ve hesap adına göre
//  namespace edilmelidir").
//
//  SECURITY: this file must never log stored values — only key names
//  and OSStatus codes may appear in logs.
//

import Foundation
import Security
import os

final class KeychainStore: SecureStore {

    private let service: String
    private let logger = AppLogger.auth

    init(service: String = (Bundle.main.bundleIdentifier ?? "com.aichat.app") + ".secure") {
        self.service = service
    }

    // MARK: - SecureStore

    func read(_ key: SecureStoreKey) throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8)
            else { throw SecureStoreError.corruptedData }
            return value
        case errSecItemNotFound:
            return nil
        default:
            logger.error("Keychain read failed for \(key.rawValue): status \(status)")
            throw SecureStoreError.unhandled(status: status)
        }
    }

    func save(_ value: String, for key: SecureStoreKey) throws {
        let data = Data(value.utf8)

        // Try update first; add if the item doesn't exist yet.
        let updateStatus = SecItemUpdate(
            baseQuery(for: key) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = baseQuery(for: key)
            addQuery[kSecValueData as String] = data
            // Accessible after first unlock — survives relaunch, not
            // exposed while the machine is locked at boot.
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                logger.error("Keychain add failed for \(key.rawValue): status \(addStatus)")
                throw SecureStoreError.unhandled(status: addStatus)
            }
        default:
            logger.error("Keychain update failed for \(key.rawValue): status \(updateStatus)")
            throw SecureStoreError.unhandled(status: updateStatus)
        }
    }

    func delete(_ key: SecureStoreKey) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        // Deleting something that isn't there is fine (idempotent logout).
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Keychain delete failed for \(key.rawValue): status \(status)")
            throw SecureStoreError.unhandled(status: status)
        }
    }

    // MARK: - Helpers

    private func baseQuery(for key: SecureStoreKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
    }
}

// MARK: - In-memory fake (tests & previews)

/// SecureStore fake — keeps values in a dictionary. Used by unit tests
/// and SwiftUI previews so they never touch the real Keychain.
final class InMemorySecureStore: SecureStore {

    private var storage: [SecureStoreKey: String] = [:]

    func read(_ key: SecureStoreKey) throws -> String? {
        storage[key]
    }

    func save(_ value: String, for key: SecureStoreKey) throws {
        storage[key] = value
    }

    func delete(_ key: SecureStoreKey) throws {
        storage.removeValue(forKey: key)
    }
}
