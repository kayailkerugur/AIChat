import Foundation

@MainActor
public protocol AIProviderRegistry: AnyObject, Sendable {
    var providers: [any AIProvider] { get }

    func reload()
    func provider(withID id: String) -> (any AIProvider)?
}

public extension AIProviderRegistry {
    var allModels: [AIModel] {
        providers.flatMap(\.supportedModels)
    }

    func resolvedProvider(forID id: String) -> (any AIProvider)? {
        provider(withID: id) ?? providers.first
    }
}
