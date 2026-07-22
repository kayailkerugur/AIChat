import Foundation

@MainActor
public final class ConfigBackedAIProviderRegistry: AIProviderRegistry {
    public private(set) var providers: [any AIProvider] = []

    private let configStore: ProviderConfigStore
    private let secureStore: any SecureStore

    public init(
        configStore: ProviderConfigStore,
        secureStore: any SecureStore
    ) {
        self.configStore = configStore
        self.secureStore = secureStore

        reload()

        configStore.onChange = { [weak self] in
            self?.reload()
        }
    }

    public func reload() {
        providers = configStore.configs.map { config in
            GenericAIProvider(
                config: config,
                secureStore: secureStore
            )
        }
    }

    public func provider(withID id: String) -> (any AIProvider)? {
        providers.first { $0.id == id }
    }
}
