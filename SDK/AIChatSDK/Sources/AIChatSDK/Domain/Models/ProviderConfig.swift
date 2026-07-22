import Foundation

public struct ProviderConfig: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var baseURL: URL
    public var requiresAPIKey: Bool
    public var supportsImages: Bool
    public var models: [CachedModel]
    public var modelsFetchedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        baseURL: URL,
        requiresAPIKey: Bool,
        supportsImages: Bool = false,
        models: [CachedModel] = [],
        modelsFetchedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.requiresAPIKey = requiresAPIKey
        self.supportsImages = supportsImages
        self.models = models
        self.modelsFetchedAt = modelsFetchedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, baseURL, requiresAPIKey, supportsImages, models, modelsFetchedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        baseURL = try container.decode(URL.self, forKey: .baseURL)
        requiresAPIKey = try container.decode(Bool.self, forKey: .requiresAPIKey)
        supportsImages = try container.decodeIfPresent(Bool.self, forKey: .supportsImages) ?? false
        models = try container.decodeIfPresent([CachedModel].self, forKey: .models) ?? []
        modelsFetchedAt = try container.decodeIfPresent(Date.self, forKey: .modelsFetchedAt)
    }

    public struct CachedModel: Codable, Equatable, Identifiable, Sendable {
        public let id: String
        public var displayName: String

        public init(id: String, displayName: String? = nil) {
            self.id = id
            self.displayName = displayName ?? id
        }
    }

    public var apiKeyStorageKey: String { "provider.\(id.uuidString).api-key" }
    public var providerID: String { id.uuidString }

    public var asAIModels: [AIModel] {
        models.map { AIModel(id: $0.id, displayName: $0.displayName, providerID: providerID) }
    }
}
