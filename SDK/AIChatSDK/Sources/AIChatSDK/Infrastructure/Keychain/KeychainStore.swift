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

@MainActor
public final class KeychainStore: SecureStore {

    private let service: String
    private let logger = SDKLogger.secureStorage

    public init(service: String) {
        self.service = service
    }

    // MARK: - SecureStore

    public func read(key: String) throws -> String? {
        var query = baseQuery(account: key)
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
            logger.error("Keychain read failed for \(key): status \(status)")
            throw SecureStoreError.unhandled(status: status)
        }
    }

    public func save(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)

        // Try update first; add if the item doesn't exist yet.
        let updateStatus = SecItemUpdate(
            baseQuery(account: key) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = baseQuery(account: key)
            addQuery[kSecValueData as String] = data
            // Accessible after first unlock — survives relaunch, not
            // exposed while the machine is locked at boot.
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                logger.error("Keychain add failed for \(key): status \(addStatus)")
                throw SecureStoreError.unhandled(status: addStatus)
            }
        default:
            logger.error("Keychain update failed for \(key): status \(updateStatus)")
            throw SecureStoreError.unhandled(status: updateStatus)
        }
    }

    public func delete(key: String) throws {
        let status = SecItemDelete(baseQuery(account: key) as CFDictionary)
        // Deleting something that isn't there is fine (idempotent logout).
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Keychain delete failed for \(key): status \(status)")
            throw SecureStoreError.unhandled(status: status)
        }
    }

    // MARK: - Helpers

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

// MARK: - In-memory fake (tests & previews)

/// SecureStore fake — keeps values in a dictionary. Used by unit tests
/// and SwiftUI previews so they never touch the real Keychain.
@MainActor
public final class InMemorySecureStore: SecureStore {

    private var storage: [String: String] = [:]

    public init() {}

    public func read(key: String) throws -> String? {
        storage[key]
    }

    public func save(_ value: String, forKey key: String) throws {
        storage[key] = value
    }

    public func delete(key: String) throws {
        storage.removeValue(forKey: key)
    }
}
