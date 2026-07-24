import Foundation

public enum AIProviderConfigurationError: LocalizedError, Equatable, Sendable {
    case noModels

    public var errorDescription: String? {
        switch self {
        case .noModels:
            return "Sağlayıcıdan model bulunamadı."
        }
    }
}

/// Reusable provider-configuration operations exposed to a host application.
///
/// The host owns the settings presentation while the SDK owns provider
/// persistence, credentials, model discovery and provider capabilities.
@MainActor
public protocol AIProviderConfigurationService: AnyObject, Sendable {
    var configurations: [ProviderConfiguration] { get }

    @discardableResult
    func addDefaultProvider() -> ProviderConfiguration

    @discardableResult
    func save(_ configuration: ProviderConfiguration) -> ProviderConfiguration

    func delete(_ configuration: ProviderConfiguration)
    func hasCredential(for configuration: ProviderConfiguration) -> Bool
    func saveCredential(_ credential: String, for configuration: ProviderConfiguration) throws
    func deleteCredential(for configuration: ProviderConfiguration) throws

    func refreshModels(
        for configuration: ProviderConfiguration,
        credential: String?
    ) async throws -> ProviderConfiguration
}

@MainActor
public final class DefaultAIProviderConfigurationService: AIProviderConfigurationService {
    private let configStore: any ProviderConfigStore
    private let secureStore: any SecureStore
    private let networkClient: any NetworkClient

    public init(
        configStore: any ProviderConfigStore,
        secureStore: any SecureStore,
        networkClient: any NetworkClient = URLSessionNetworkClient()
    ) {
        self.configStore = configStore
        self.secureStore = secureStore
        self.networkClient = networkClient
    }

    public var configurations: [ProviderConfiguration] {
        configStore.configs
    }

    @discardableResult
    public func addDefaultProvider() -> ProviderConfiguration {
        let configuration = ProviderConfiguration(
            name: "Yeni Sağlayıcı",
            baseURL: URL(string: "http://localhost:11434/v1")!,
            requiresAPIKey: false,
            supportsImages: false,
            models: [.init(id: "llama3")]
        )
        configStore.save(configuration)
        return configuration
    }

    @discardableResult
    public func save(_ configuration: ProviderConfiguration) -> ProviderConfiguration {
        var normalized = configuration
        normalized.supportsImages = Self.inferImageSupport(
            baseURL: normalized.baseURL,
            models: normalized.models
        )
        normalized.modelsFetchedAt = Date()
        configStore.save(normalized)
        return normalized
    }

    public func delete(_ configuration: ProviderConfiguration) {
        do {
            try secureStore.delete(key: configuration.apiKeyStorageKey)
        } catch {
            SDKLogger.providerConfiguration.error(
                "Provider credential delete failed: \(String(describing: error))"
            )
        }
        configStore.delete(id: configuration.id)
    }

    public func hasCredential(for configuration: ProviderConfiguration) -> Bool {
        ((try? secureStore.read(key: configuration.apiKeyStorageKey)) ?? nil)?.isEmpty == false
    }

    public func saveCredential(
        _ credential: String,
        for configuration: ProviderConfiguration
    ) throws {
        try secureStore.save(credential, forKey: configuration.apiKeyStorageKey)
    }

    public func deleteCredential(for configuration: ProviderConfiguration) throws {
        try secureStore.delete(key: configuration.apiKeyStorageKey)
    }

    public func refreshModels(
        for configuration: ProviderConfiguration,
        credential: String? = nil
    ) async throws -> ProviderConfiguration {
        if configuration.requiresAPIKey,
           let credential,
           !credential.isEmpty {
            try saveCredential(credential, for: configuration)
        }

        let provider = GenericAIProvider(
            config: configuration,
            secureStore: secureStore,
            networkClient: networkClient
        )
        let models = try await provider.refreshModels()
        guard !models.isEmpty else {
            throw AIProviderConfigurationError.noModels
        }

        var refreshed = configuration
        refreshed.models = models.map {
            ProviderConfiguration.CachedModel(
                id: $0.id,
                displayName: $0.displayName
            )
        }
        refreshed.supportsImages = Self.inferImageSupport(
            baseURL: refreshed.baseURL,
            models: refreshed.models
        )
        refreshed.modelsFetchedAt = Date()
        configStore.save(refreshed)
        return refreshed
    }

    private static func inferImageSupport(
        baseURL: URL,
        models: [ProviderConfiguration.CachedModel]
    ) -> Bool {
        let host = (baseURL.host() ?? "").lowercased()
        if host == "localhost" || host == "127.0.0.1" || host == "::1" {
            return false
        }
        if host.contains("generativelanguage.googleapis.com") {
            return true
        }
        if host.contains("api.openai.com") {
            return models.contains { model in
                let id = model.id.lowercased()
                return id.contains("gpt-4o")
                    || id.contains("gpt-4.1")
                    || id.contains("vision")
            }
        }
        return false
    }
}
