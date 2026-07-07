//
//  AppEnvironment.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//
//  Central configuration for external services (spec §6.2: "OAuth ve
//  AI servisleri için environment/configuration katmanı bulunmalı;
//  hard-coded URL ve model isimlerinden kaçınılmalıdır").
//
//  Contains NO secrets — API keys and tokens live in Keychain behind
//  SecureStore. This file may hold endpoints, versions and client IDs
//  (a public-client OAuth client ID is not a secret by design).
//

import Foundation

struct AppEnvironment {

    // MARK: - Gemini

    struct GeminiConfiguration {
        /// e.g. https://generativelanguage.googleapis.com
        let baseURL: URL
        /// API version path component, e.g. "v1beta"
        let apiVersion: String

        /// Builds the streaming endpoint for a model:
        /// {base}/{version}/models/{model}:streamGenerateContent?alt=sse
        func streamURL(forModel modelID: String) -> URL {
            baseURL
                .appending(path: apiVersion)
                .appending(path: "models")
                .appending(path: "\(modelID):streamGenerateContent")
                .appending(queryItems: [URLQueryItem(name: "alt", value: "sse")])
        }
    }

    let gemini: GeminiConfiguration

    // OAuth configuration lands here in the Days 21–25 phase
    // (authorization endpoint, token endpoint, client ID, redirect URI).

    // MARK: - Environments

    static let production = AppEnvironment(
        gemini: GeminiConfiguration(
            baseURL: URL(string: "https://generativelanguage.googleapis.com")!,
            apiVersion: "v1beta"
        )
    )
}
