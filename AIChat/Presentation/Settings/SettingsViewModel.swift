//
//  SettingsViewModel.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//

import Foundation
import AIChatSDK
import Observation
import os

@MainActor
@Observable
final class SettingsViewModel {

    // MARK: - Observed state

    var selectedProviderID: UUID? {
        didSet { loadSelectedProviderDrafts() }
    }

    var providerNameDraft = ""
    var baseURLDraft = ""
    var requiresAPIKeyDraft = true
    var modelsDraft = ""
    var apiKeyDraft = ""

    private(set) var hasStoredAPIKey = false
    private(set) var isRefreshingModels = false
    private(set) var infoMessage: String?
    private(set) var errorMessage: String?

    /// Picker tag for NEW conversations. Format: "{providerID}|{modelID}".
    var selectedModelTag: String {
        didSet { persistDefaultModelTag() }
    }

    var providerConfigs: [ProviderConfig] {
        providerConfigStore.configs
    }

    var selectedProvider: ProviderConfig? {
        guard let selectedProviderID else { return nil }
        return providerConfigs.first { $0.id == selectedProviderID }
    }

    var selectedProviderModelsFetchedText: String? {
        guard let date = selectedProvider?.modelsFetchedAt else { return nil }
        return Self.modelsFetchedFormatter.localizedString(for: date, relativeTo: Date())
    }

    var canSaveProvider: Bool {
        !providerNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && URL(string: baseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    var providerSections: [ProviderSection] {
        providerConfigs.map { config in
            ProviderSection(
                id: config.providerID,
                name: config.name,
                models: config.asAIModels
            )
        }
    }

    // MARK: - Picker content

    struct ProviderSection: Identifiable {
        let id: String
        let name: String
        let models: [AIModel]
    }

    // MARK: - Dependencies

    private let secureStore: SecureStore
    private let registry: AIProviderRegistry
    private let providerConfigStore: ProviderConfigStore
    private let authService: AuthService
    private let logger = AppLogger.auth

    private static let modelKey = "settings.defaultModelID"
    private static let providerKey = "settings.defaultProviderID"
    private static let modelsFetchedFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    init(
        secureStore: SecureStore,
        registry: AIProviderRegistry,
        providerConfigStore: ProviderConfigStore,
        authService: AuthService
    ) {
        self.secureStore = secureStore
        self.registry = registry
        self.providerConfigStore = providerConfigStore
        self.authService = authService

        let preferred = Self.preferredModel(in: registry)
        self.selectedModelTag = Self.tag(
            providerID: preferred.providerID,
            modelID: preferred.id
        )
        self.selectedProviderID = providerConfigStore.configs.first?.id

        loadSelectedProviderDrafts()
    }

    /// Reads the user's preferred default model across all providers.
    static func preferredModel(in registry: AIProviderRegistry) -> AIModel {
        let storedProviderID = UserDefaults.standard.string(forKey: providerKey)
        let storedModelID = UserDefaults.standard.string(forKey: modelKey)

        if let storedProviderID,
           let storedModelID,
           let model = registry.allModels.first(where: {
               $0.providerID == storedProviderID && $0.id == storedModelID
           }) {
            return model
        }

        if let storedModelID,
           let model = registry.allModels.first(where: { $0.id == storedModelID }) {
            return model
        }

        return registry.allModels.first
            ?? AIModel(id: "", displayName: "-", providerID: "")
    }

    // MARK: - Provider intents

    func addProvider() {
        let config = ProviderConfig(
            name: "Yeni Sağlayıcı",
            baseURL: URL(string: "http://localhost:11434/v1")!,
            requiresAPIKey: false,
            supportsImages: false,
            models: [.init(id: "llama3")]
        )
        providerConfigStore.save(config)
        selectedProviderID = config.id
        selectedModelTag = Self.tag(providerID: config.providerID, modelID: "llama3")
        persistDefaultModelTag()
        infoMessage = "Sağlayıcı eklendi."
        errorMessage = nil
    }

    func saveSelectedProvider() {
        guard let selectedProvider else { return }

        let trimmedName = providerNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseURL = baseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let baseURL = URL(string: trimmedBaseURL),
              !trimmedName.isEmpty
        else {
            errorMessage = "Sağlayıcı adı ve geçerli bir base URL gerekli."
            return
        }

        var updated = selectedProvider
        updated.name = trimmedName
        updated.baseURL = baseURL
        updated.requiresAPIKey = requiresAPIKeyDraft
        updated.models = parsedModels
        updated.supportsImages = Self.inferImageSupport(
            baseURL: baseURL,
            models: updated.models
        )
        updated.modelsFetchedAt = Date()

        providerConfigStore.save(updated)
        selectedProviderID = updated.id

        if !updated.asAIModels.contains(where: {
            Self.tag(providerID: $0.providerID, modelID: $0.id) == selectedModelTag
        }), let firstModel = updated.asAIModels.first {
            selectedModelTag = Self.tag(
                providerID: firstModel.providerID,
                modelID: firstModel.id
            )
        }

        infoMessage = "Sağlayıcı kaydedildi."
        errorMessage = nil
    }

    func refreshSelectedProviderModels() async {
        guard let selectedProvider else { return }

        let trimmedName = providerNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseURL = baseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let baseURL = URL(string: trimmedBaseURL),
              !trimmedName.isEmpty
        else {
            errorMessage = "Model çekmek için sağlayıcı adı ve geçerli bir base URL gerekli."
            return
        }

        isRefreshingModels = true
        defer { isRefreshingModels = false }

        var refreshedConfig = selectedProvider
        refreshedConfig.name = trimmedName
        refreshedConfig.baseURL = baseURL
        refreshedConfig.requiresAPIKey = requiresAPIKeyDraft

        if requiresAPIKeyDraft {
            let trimmedKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKey.isEmpty {
                do {
                    try secureStore.save(trimmedKey, forKey: refreshedConfig.apiKeyStorageKey)
                    apiKeyDraft = ""
                    refreshKeyStatus()
                } catch {
                    logger.error("API key save before model refresh failed: \(String(describing: error))")
                    errorMessage = "API anahtarı kaydedilemedi."
                    return
                }
            }
        }

        do {
            let provider = GenericAIProvider(
                config: refreshedConfig,
                secureStore: secureStore
            )
            let models = try await provider.refreshModels()
            guard !models.isEmpty else {
                errorMessage = "Sağlayıcıdan model bulunamadı."
                return
            }

            refreshedConfig.models = models.map {
                ProviderConfig.CachedModel(
                    id: $0.id,
                    displayName: $0.displayName
                )
            }
            refreshedConfig.supportsImages = Self.inferImageSupport(
                baseURL: baseURL,
                models: refreshedConfig.models
            )
            refreshedConfig.modelsFetchedAt = Date()

            providerConfigStore.save(refreshedConfig)
            selectedProviderID = refreshedConfig.id
            modelsDraft = refreshedConfig.models.map(\.id).joined(separator: "\n")

            if !models.contains(where: {
                Self.tag(providerID: $0.providerID, modelID: $0.id) == selectedModelTag
            }), let firstModel = models.first {
                selectedModelTag = Self.tag(
                    providerID: firstModel.providerID,
                    modelID: firstModel.id
                )
            }

            infoMessage = "\(models.count) model yüklendi."
            errorMessage = nil
        } catch let error as AIError {
            errorMessage = error.errorDescription ?? "Modeller çekilemedi."
        } catch {
            logger.error("Model refresh failed: \(String(describing: error))")
            errorMessage = "Modeller çekilemedi."
        }
    }

    func deleteSelectedProvider() {
        guard let selectedProvider else { return }

        do {
            try secureStore.delete(key: selectedProvider.apiKeyStorageKey)
        } catch {
            logger.error("Provider API key delete failed: \(String(describing: error))")
        }

        providerConfigStore.delete(id: selectedProvider.id)
        selectedProviderID = providerConfigs.first?.id

        if let firstModel = registry.allModels.first {
            selectedModelTag = Self.tag(
                providerID: firstModel.providerID,
                modelID: firstModel.id
            )
        }

        infoMessage = "Sağlayıcı silindi."
        errorMessage = nil
    }

    // MARK: - API key intents

    func saveAPIKey() {
        guard let selectedProvider else { return }

        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try secureStore.save(trimmed, forKey: selectedProvider.apiKeyStorageKey)
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
        guard let selectedProvider else { return }

        do {
            try secureStore.delete(key: selectedProvider.apiKeyStorageKey)
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

    private var parsedModels: [ProviderConfig.CachedModel] {
        modelsDraft
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { ProviderConfig.CachedModel(id: $0) }
    }

    private func loadSelectedProviderDrafts() {
        guard let selectedProvider else {
            providerNameDraft = ""
            baseURLDraft = ""
            requiresAPIKeyDraft = true
            modelsDraft = ""
            apiKeyDraft = ""
            hasStoredAPIKey = false
            return
        }

        providerNameDraft = selectedProvider.name
        baseURLDraft = selectedProvider.baseURL.absoluteString
        requiresAPIKeyDraft = selectedProvider.requiresAPIKey
        modelsDraft = selectedProvider.models.map(\.id).joined(separator: "\n")
        apiKeyDraft = ""
        refreshKeyStatus()
    }

    private func refreshKeyStatus() {
        guard let selectedProvider else {
            hasStoredAPIKey = false
            return
        }
        hasStoredAPIKey = ((try? secureStore.read(key: selectedProvider.apiKeyStorageKey)) ?? nil)?.isEmpty == false
    }

    private func persistDefaultModelTag() {
        let parts = selectedModelTag.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        UserDefaults.standard.set(parts[0], forKey: Self.providerKey)
        UserDefaults.standard.set(parts[1], forKey: Self.modelKey)
    }

    static func tag(providerID: String, modelID: String) -> String {
        "\(providerID)|\(modelID)"
    }

    private static func inferImageSupport(
        baseURL: URL,
        models: [ProviderConfig.CachedModel]
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
