//
//  ProviderConfigStoreTests.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 9.07.2026.
//

import XCTest
@testable import AIChat

@MainActor
final class ProviderConfigStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var store: UserDefaultsProviderConfigStore!
    private let suiteName = "ProviderConfigStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = UserDefaultsProviderConfigStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeConfig(name: String = "Test Sağlayıcı") -> ProviderConfig {
        ProviderConfig(
            name: name,
            baseURL: URL(string: "https://example.com/v1")!,
            requiresAPIKey: true,
            presetID: "custom"
        )
    }

    func test_save_insertsNewConfig() {
        let config = makeConfig()

        store.save(config)

        XCTAssertEqual(store.configs, [config])
    }

    func test_save_updatesExistingConfigById() {
        var config = makeConfig(name: "Eski Ad")
        store.save(config)

        config.name = "Yeni Ad"
        config.models = [.init(id: "model-1", displayName: "Model 1")]
        store.save(config)

        XCTAssertEqual(store.configs.count, 1)
        XCTAssertEqual(store.configs[0].name, "Yeni Ad")
        XCTAssertEqual(store.configs[0].models.first?.id, "model-1")
    }

    func test_delete_removesOnlyThatConfig() {
        let keep = makeConfig(name: "Kalacak")
        let remove = makeConfig(name: "Silinecek")
        store.save(keep)
        store.save(remove)

        store.delete(id: remove.id)

        XCTAssertEqual(store.configs, [keep])
    }

    func test_configs_surviveReload() {
        let config = makeConfig()
        store.save(config)

        // A fresh store instance = app relaunch.
        let reloaded = UserDefaultsProviderConfigStore(defaults: defaults)

        XCTAssertEqual(reloaded.configs, [config])
    }

    func test_corruptedData_loadsAsEmptyWithoutCrashing() {
        defaults.set(Data("bozuk json".utf8), forKey: "providers.configs")

        let store = UserDefaultsProviderConfigStore(defaults: defaults)

        XCTAssertTrue(store.configs.isEmpty)
    }

    func test_mutations_fireOnChange() {
        var fireCount = 0
        store.onChange = { fireCount += 1 }

        let config = makeConfig()
        store.save(config)
        store.delete(id: config.id)

        XCTAssertEqual(fireCount, 2)
    }

    func test_apiKeyStorageKey_isUniquePerConfig() {
        let first = makeConfig()
        let second = makeConfig()

        XCTAssertNotEqual(first.apiKeyStorageKey, second.apiKeyStorageKey)
        XCTAssertTrue(first.apiKeyStorageKey.hasPrefix("provider."))
    }
}
