//
//  ProviderConfig.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 9.07.2026.
//

import Foundation

struct ProviderConfig: Codable, Identifiable, Equatable {

    /// A model as cached from the provider's GET /models endpoint —
    /// users never type model names (team review, item 2).
    struct CachedModel: Codable, Equatable, Identifiable {
        let id: String        // API-side identifier, e.g. "gemini-2.5-flash"
        var displayName: String
    }

    /// Registry identity. Conversation.providerID stores this UUID's
    /// string form, so chats stay bound to the config they started with.
    let id: UUID
    var name: String
    var baseURL: URL
    var requiresAPIKey: Bool
    /// Which preset this config was created from ("gemini", "ollama"…),
    /// nil for fully custom endpoints. Informational only.
    var presetID: String?

    var models: [CachedModel]
    var modelsFetchedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: URL,
        requiresAPIKey: Bool,
        presetID: String? = nil,
        models: [CachedModel] = [],
        modelsFetchedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.requiresAPIKey = requiresAPIKey
        self.presetID = presetID
        self.models = models
        self.modelsFetchedAt = modelsFetchedAt
    }

    /// Dynamic Keychain account for this provider's API key.
    /// The key VALUE never touches this Codable struct.
    var apiKeyStorageKey: String {
        "provider.\(id.uuidString).api-key"
    }

    /// Bridge to the domain type the rest of the app speaks.
    var asAIModels: [AIModel] {
        models.map {
            AIModel(id: $0.id, displayName: $0.displayName, providerID: id.uuidString)
        }
    }
}

// MARK: - Presets

/// Quick-start templates shown in the "add provider" UI. Picking one
/// prefills the endpoint and whether a key is needed; "custom" leaves
/// the URL to the user (self-hosted / corporate endpoints).
struct ProviderPreset: Identifiable, Equatable {

    let id: String
    let name: String
    let baseURL: URL?          // nil → user must type it (custom)
    let requiresAPIKey: Bool
    let keyHelpURL: URL?       // "where do I get a key" link

    static let gemini = ProviderPreset(
        id: "gemini",
        name: "Google Gemini",
        // Google's OpenAI-compatible endpoint for Gemini models.
        baseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta/openai")!,
        requiresAPIKey: true,
        keyHelpURL: URL(string: "https://aistudio.google.com/apikey")
    )

    static let openAI = ProviderPreset(
        id: "openai",
        name: "OpenAI",
        baseURL: URL(string: "https://api.openai.com/v1")!,
        requiresAPIKey: true,
        keyHelpURL: URL(string: "https://platform.openai.com/api-keys")
    )

    static let ollama = ProviderPreset(
        id: "ollama",
        name: "Ollama (yerel)",
        baseURL: URL(string: "http://localhost:11434/v1")!,
        requiresAPIKey: false,
        keyHelpURL: nil
    )

    static let lmStudio = ProviderPreset(
        id: "lmstudio",
        name: "LM Studio (yerel)",
        baseURL: URL(string: "http://localhost:1234/v1")!,
        requiresAPIKey: false,
        keyHelpURL: nil
    )

    static let custom = ProviderPreset(
        id: "custom",
        name: "Özel (OpenAI-uyumlu)",
        baseURL: nil,
        requiresAPIKey: true,
        keyHelpURL: nil
    )

    static let all: [ProviderPreset] = [gemini, openAI, ollama, lmStudio, custom]

    /// Builds a fresh config from this preset. Returns nil only when a
    /// custom preset is used without providing a URL.
    func makeConfig(name: String? = nil, baseURL overrideURL: URL? = nil) -> ProviderConfig? {
        guard let url = overrideURL ?? self.baseURL else { return nil }
        return ProviderConfig(
            name: name ?? self.name,
            baseURL: url,
            requiresAPIKey: requiresAPIKey,
            presetID: id
        )
    }
}
