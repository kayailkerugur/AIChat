//
//  SettingsViewModel.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//

import Foundation
import AIChatSDK
import Observation

@MainActor
@Observable
final class SettingsViewModel {

    // MARK: - Observed state

    var selectedProviderID: UUID? {
        didSet {
            loadSelectedProviderDrafts()
            selectModelForSelectedProviderIfNeeded()
        }
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
        providerConfigurationService.configurations
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

    var selectedProviderModels: [AIModel] {
        selectedProvider?.asAIModels ?? []
    }

    // MARK: - Picker content

    struct ProviderSection: Identifiable {
        let id: String
        let name: String
        let models: [AIModel]
    }

    // MARK: - Dependencies

    private let registry: AIProviderRegistry
    private let providerConfigurationService: AIProviderConfigurationService
    private let authService: AuthService

    private static let modelKey = "settings.defaultModelID"
    private static let providerKey = "settings.defaultProviderID"
    private static let modelsFetchedFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    init(
        registry: AIProviderRegistry,
        providerConfigurationService: AIProviderConfigurationService,
        authService: AuthService
    ) {
        self.registry = registry
        self.providerConfigurationService = providerConfigurationService
        self.authService = authService

        let preferred = Self.preferredModel(in: registry)
        self.selectedModelTag = Self.tag(
            providerID: preferred.providerID,
            modelID: preferred.id
        )
        self.selectedProviderID = providerConfigurationService.configurations
            .first { $0.providerID == preferred.providerID }?.id
            ?? providerConfigurationService.configurations.first?.id

        loadSelectedProviderDrafts()
        selectModelForSelectedProviderIfNeeded()
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
        let config = providerConfigurationService.addDefaultProvider()
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
        updated = providerConfigurationService.save(updated)
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
                    try providerConfigurationService.saveCredential(
                        trimmedKey,
                        for: refreshedConfig
                    )
                    apiKeyDraft = ""
                    refreshKeyStatus()
                } catch {
                    errorMessage = "API anahtarı kaydedilemedi."
                    return
                }
            }
        }

        do {
            refreshedConfig = try await providerConfigurationService.refreshModels(
                for: refreshedConfig,
                credential: nil
            )
            let models = refreshedConfig.asAIModels
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
        } catch let error as AIProviderConfigurationError {
            errorMessage = error.errorDescription ?? "Modeller çekilemedi."
        } catch let error as AIError {
            errorMessage = error.errorDescription ?? "Modeller çekilemedi."
        } catch {
            errorMessage = "Modeller çekilemedi."
        }
    }

    func deleteSelectedProvider() {
        guard let selectedProvider else { return }

        providerConfigurationService.delete(selectedProvider)
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
            try providerConfigurationService.saveCredential(trimmed, for: selectedProvider)
            apiKeyDraft = ""
            infoMessage = "API anahtarı güvenli olarak kaydedildi."
            errorMessage = nil
            refreshKeyStatus()
        } catch {
            errorMessage = "API anahtarı kaydedilemedi."
        }
    }

    func deleteAPIKey() {
        guard let selectedProvider else { return }

        do {
            try providerConfigurationService.deleteCredential(for: selectedProvider)
            infoMessage = "API anahtarı silindi."
            errorMessage = nil
            refreshKeyStatus()
        } catch {
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
        hasStoredAPIKey = providerConfigurationService.hasCredential(for: selectedProvider)
    }

    private func selectModelForSelectedProviderIfNeeded() {
        guard let selectedProvider else { return }
        let models = selectedProvider.asAIModels
        guard !models.isEmpty else {
            selectedModelTag = ""
            return
        }

        let currentTagBelongsToProvider = models.contains {
            Self.tag(providerID: $0.providerID, modelID: $0.id)
                == selectedModelTag
        }
        guard !currentTagBelongsToProvider else { return }

        let storedProviderID = UserDefaults.standard.string(
            forKey: Self.providerKey
        )
        let storedModelID = UserDefaults.standard.string(
            forKey: Self.modelKey
        )
        let model = models.first {
            $0.providerID == storedProviderID && $0.id == storedModelID
        } ?? models[0]
        selectedModelTag = Self.tag(
            providerID: model.providerID,
            modelID: model.id
        )
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

}
