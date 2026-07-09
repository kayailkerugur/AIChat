//
//  ProviderConfigStore.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 9.07.2026.
//

import Foundation
import os

@MainActor
protocol ProviderConfigStore: AnyObject {
    var configs: [ProviderConfig] { get }
    /// Insert or update (matched by id).
    func save(_ config: ProviderConfig)
    func delete(id: UUID)
    /// Fired after every mutation — the dynamic registry listens to
    /// rebuild its provider instances.
    var onChange: (() -> Void)? { get set }
}

@MainActor
final class UserDefaultsProviderConfigStore: ProviderConfigStore {

    private(set) var configs: [ProviderConfig] = []
    var onChange: (() -> Void)?

    private let defaults: UserDefaults
    private let storageKey = "providers.configs"
    private let logger = AppLogger.persistence

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func save(_ config: ProviderConfig) {
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
        } else {
            configs.append(config)
        }
        persist()
        onChange?()
    }

    func delete(id: UUID) {
        configs.removeAll { $0.id == id }
        persist()
        onChange?()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            configs = []
            return
        }
        do {
            configs = try JSONDecoder().decode([ProviderConfig].self, from: data)
        } catch {
            // A corrupted blob must not crash the app — start empty,
            // the user can re-add providers.
            logger.error("Provider configs decode failed: \(error.localizedDescription)")
            configs = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(configs)
            defaults.set(data, forKey: storageKey)
        } catch {
            logger.error("Provider configs encode failed: \(error.localizedDescription)")
        }
    }
}
