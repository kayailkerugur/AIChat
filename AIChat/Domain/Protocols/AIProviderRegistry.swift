//
//  AIProviderRegistry.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 7.07.2026.
//
//  Registry of available AI providers. This is what makes the app
//  multi-provider-ready: Conversation already stores providerID, the
//  registry resolves it back to a concrete provider at runtime.
//
//  Adding a future provider (OpenAI, Anthropic, local model…) is:
//    1. implement AIProvider in a new file under Data/Providers,
//    2. add its API key to SecureStoreKey + a Settings field if needed,
//    3. append ONE line to the registry in AppDependencies.
//  Nothing above the protocol boundary changes.
//

import Foundation

protocol AIProviderRegistry: AnyObject {
    var providers: [AIProvider] { get }

    func reload()
    func provider(withID id: String) -> AIProvider?
}

extension AIProviderRegistry {

    var allModels: [AIModel] {
        providers.flatMap(\.supportedModels)
    }

    func resolvedProvider(forID id: String) -> AIProvider? {
        provider(withID: id) ?? providers.first
    }
}

@MainActor
final class ConfigBackedAIProviderRegistry: AIProviderRegistry {

    private(set) var providers: [AIProvider] = []

    private let configStore: ProviderConfigStore
    private let secureStore: SecureStore

    init(
        configStore: ProviderConfigStore,
        secureStore: SecureStore
    ) {
        self.configStore = configStore
        self.secureStore = secureStore

        reload()

        configStore.onChange = { [weak self] in
            self?.reload()
        }
    }

    func reload() {
        providers = configStore.configs.map { config in
            GenericAIProvider(
                config: config,
                secureStore: secureStore
            )
        }
    }

    func provider(withID id: String) -> AIProvider? {
        providers.first { $0.id == id }
    }
}
