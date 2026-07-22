import XCTest
@testable import AIChatSDK

final class ConfigBackedAIProviderRegistryTests: XCTestCase {
    @MainActor
    func test_registryReflectsConfigStoreMutations() {
        let suiteName = "ConfigBackedAIProviderRegistryTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Test UserDefaults suite could not be created")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configStore = UserDefaultsProviderConfigStore(defaults: defaults)
        let registry = ConfigBackedAIProviderRegistry(
            configStore: configStore,
            secureStore: InMemorySecureStore()
        )
        let config = ProviderConfig(
            name: "Test Provider",
            baseURL: URL(string: "https://example.com/v1")!,
            requiresAPIKey: true
        )

        XCTAssertTrue(registry.providers.isEmpty)

        configStore.save(config)
        XCTAssertEqual(registry.providers.map(\.id), [config.id.uuidString])
        XCTAssertNotNil(registry.provider(withID: config.id.uuidString))

        configStore.delete(id: config.id)
        XCTAssertTrue(registry.providers.isEmpty)
    }
}
