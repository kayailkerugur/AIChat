//
//  SettingsViewModel.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//
//  UPDATED (multi-provider step): the model picker now spans ALL
//  registered providers, grouped into sections. Selecting a model
//  implicitly selects its provider — new conversations carry both
//  (Conversation.providerID + modelID).
//

import Foundation
import Observation
import os

@MainActor
@Observable
final class SettingsViewModel {

    // MARK: - Observed state

    /// Draft text in the key field — cleared after save, never
    /// pre-filled from Keychain.
    var apiKeyDraft: String = ""
    private(set) var hasStoredAPIKey = false
    private(set) var infoMessage: String?
    private(set) var errorMessage: String?

    /// Default model for NEW conversations (existing ones keep theirs).
    var selectedModelID: String {
        didSet {
            UserDefaults.standard.set(selectedModelID, forKey: Self.modelKey)
        }
    }

    // MARK: - Picker content

    struct ProviderSection: Identifiable {
        let id: String
        let name: String
        let models: [AIModel]
    }

    var providerSections: [ProviderSection] {
        registry.providers.map { provider in
            ProviderSection(
                id: provider.id,
                name: Self.displayName(forProviderID: provider.id),
                models: provider.supportedModels
            )
        }
    }

    // MARK: - Dependencies

    private let secureStore: SecureStore
    private let registry: AIProviderRegistry
    private let authService: AuthService
    private let logger = AppLogger.auth

    private static let modelKey = "settings.defaultModelID"

    init(
        secureStore: SecureStore,
        registry: AIProviderRegistry,
        authService: AuthService
    ) {
        self.secureStore = secureStore
        self.registry = registry
        self.authService = authService

        // Model preference is NOT a secret — UserDefaults is the right
        // home for it (unlike the API key).
        self.selectedModelID = Self.preferredModel(in: registry).id

        refreshKeyStatus()
    }

    /// Reads the user's preferred default model across all providers,
    /// falling back to the first model of the first provider.
    static func preferredModel(in registry: AIProviderRegistry) -> AIModel {
        if let storedID = UserDefaults.standard.string(forKey: modelKey),
           let model = registry.allModels.first(where: { $0.id == storedID }) {
            return model
        }
        // Registry guarantees at least one provider; a provider with an
        // empty model list would be a programmer error surfaced here.
        return registry.allModels.first
            ?? AIModel(id: "", displayName: "—", providerID: "")
    }

    private static func displayName(forProviderID id: String) -> String {
        switch id {
        case "gemini": return "Google Gemini"
        case "mock":   return "Mock (Test)"
        default:       return id.capitalized
        }
    }

    // MARK: - API key intents

    func saveAPIKey() {
        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try secureStore.save(trimmed, for: .geminiAPIKey)
            apiKeyDraft = ""
            infoMessage = "API anahtarı güvenli olarak kaydedildi."
            errorMessage = nil
            refreshKeyStatus()
        } catch {
            logger.error("API key save failed: \(String(describing: error))")
            errorMessage = "API anahtarı kaydedilemedi."
        }
    }

    func deleteAPIKey() {
        do {
            try secureStore.delete(.geminiAPIKey)
            infoMessage = "API anahtarı silindi."
            errorMessage = nil
            refreshKeyStatus()
        } catch {
            logger.error("API key delete failed: \(String(describing: error))")
            errorMessage = "API anahtarı silinemedi."
        }
    }

    func dismissMessages() {
        infoMessage = nil
        errorMessage = nil
    }

    // MARK: - Session

    func logout() async {
        await authService.logout()
    }

    // MARK: - Helpers

    private func refreshKeyStatus() {
        hasStoredAPIKey = ((try? secureStore.read(.geminiAPIKey)) ?? nil)?.isEmpty == false
    }
}
