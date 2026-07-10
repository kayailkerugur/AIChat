//
//  ProviderConfig.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 9.07.2026.
//

import Foundation

struct ProviderConfig: Codable, Identifiable, Equatable {

    /// Kullanıcının uygulama içinden eklediği AI sağlayıcı.
    /// Örnekler:
    /// - Google Gemini OpenAI-compatible endpoint
    /// - OpenAI
    /// - Ollama local endpoint
    /// - LM Studio local endpoint
    /// - Kurumsal / custom OpenAI-compatible endpoint
    let id: UUID

    var name: String
    var baseURL: URL
    var requiresAPIKey: Bool

    /// OpenAI-compatible endpoint kullanan provider'larda genelde:
    /// GET {baseURL}/models
    /// POST {baseURL}/chat/completions
    ///
    /// Bazı local endpoint'lerde baseURL sonuna /v1 eklenmiş olabilir.
    /// Bu yüzden baseURL'i kullanıcıdan tam alınır.
    var models: [CachedModel]
    var modelsFetchedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: URL,
        requiresAPIKey: Bool,
        models: [CachedModel] = [],
        modelsFetchedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.requiresAPIKey = requiresAPIKey
        self.models = models
        self.modelsFetchedAt = modelsFetchedAt
    }

    struct CachedModel: Codable, Equatable, Identifiable {
        let id: String
        var displayName: String

        init(id: String, displayName: String? = nil) {
            self.id = id
            self.displayName = displayName ?? id
        }
    }

    /// Her provider kaydı kendi API key hesabını kullanır.
    /// Key değeri bu Codable modelin içine asla girmez.
    var apiKeyStorageKey: String {
        "provider.\(id.uuidString).api-key"
    }

    /// Conversation.providerID artık bu config'in UUID string'i olacak.
    var providerID: String {
        id.uuidString
    }

    /// Settings / Sidebar / Chat tarafının kullandığı domain modeline geçiş.
    var asAIModels: [AIModel] {
        models.map {
            AIModel(
                id: $0.id,
                displayName: $0.displayName,
                providerID: providerID
            )
        }
    }
}
