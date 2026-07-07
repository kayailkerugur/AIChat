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

    // MARK: - Google OAuth

    struct GoogleOAuthConfiguration {
        /// OAuth client ID from Google Cloud Console (iOS client type).
        /// NOT a secret for public clients — it ships in the binary by
        /// design; PKCE is what protects the flow (see design note §3).
        let clientID: String

        let authorizationEndpoint: URL
        let tokenEndpoint: URL
        /// OpenID userinfo endpoint — used to fill AuthSession's
        /// displayName/email after login.
        let userInfoEndpoint: URL

        let scopes: [String]

        /// Google's reversed-client-ID redirect:
        /// com.googleusercontent.apps.XXXX:/oauth2redirect
        /// Derived from clientID so the two can never drift apart.
        var redirectURI: String {
            "\(reversedClientID):/oauth2redirect"
        }

        /// The custom URL scheme that must be registered in Xcode
        /// (Info → URL Types): com.googleusercontent.apps.XXXX
        var reversedClientID: String {
            let suffix = ".apps.googleusercontent.com"
            guard clientID.hasSuffix(suffix) else { return clientID }
            let identifier = String(clientID.dropLast(suffix.count))
            return "com.googleusercontent.apps.\(identifier)"
        }
    }

    let googleOAuth: GoogleOAuthConfiguration

    // MARK: - Environments

    static let production = AppEnvironment(
        gemini: GeminiConfiguration(
            baseURL: URL(string: "https://generativelanguage.googleapis.com")!,
            apiVersion: "v1beta"
        ),
        googleOAuth: GoogleOAuthConfiguration(
            clientID: "322950785121-eg4r8f9k787iecdlnt3ike6as4el1flm.apps.googleusercontent.com",
            authorizationEndpoint: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
            tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!,
            userInfoEndpoint: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!,
            scopes: ["openid", "email", "profile"]
        )
    )
}
