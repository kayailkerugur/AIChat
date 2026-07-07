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
    /// All registered providers. Order matters: the first one is the
    /// fallback when a stored providerID can't be resolved.
    var providers: [AIProvider] { get }
}

extension AIProviderRegistry {

    func provider(withID id: String) -> AIProvider? {
        providers.first { $0.id == id }
    }

    /// Resolves a conversation's provider, falling back to the first
    /// registered one (e.g. chats created before a provider was removed).
    func resolvedProvider(forID id: String) -> AIProvider {
        provider(withID: id) ?? providers[0]
    }

    var allModels: [AIModel] {
        providers.flatMap(\.supportedModels)
    }
}

final class DefaultAIProviderRegistry: AIProviderRegistry {

    let providers: [AIProvider]

    init(providers: [AIProvider]) {
        precondition(!providers.isEmpty, "Registry needs at least one provider")
        self.providers = providers
    }
}
