//
//  SettingsViewModel.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
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

    var availableModels: [AIModel] { aiProvider.supportedModels }

    // MARK: - Dependencies

    private let secureStore: SecureStore
    private let aiProvider: AIProvider
    private let authService: AuthService
    private let logger = AppLogger.auth

    private static let modelKey = "settings.defaultModelID"

    /// Reads the user's preferred default model (falls back to the
    /// provider's first model). Used when creating new conversations.
    static func preferredModelID(for provider: AIProvider) -> String {
        UserDefaults.standard.string(forKey: modelKey)
            ?? provider.supportedModels.first?.id
            ?? ""
    }

    init(
        secureStore: SecureStore,
        aiProvider: AIProvider,
        authService: AuthService
    ) {
        self.secureStore = secureStore
        self.aiProvider = aiProvider
        self.authService = authService

        // Model preference is NOT a secret — UserDefaults is the right
        // home for it (unlike the API key).
        let stored = UserDefaults.standard.string(forKey: Self.modelKey)
        self.selectedModelID = stored
            ?? aiProvider.supportedModels.first?.id
            ?? ""

        refreshKeyStatus()
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
