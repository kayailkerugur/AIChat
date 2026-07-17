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

    static var production: AppEnvironment {
        production(googleOAuth: nil)
    }

    static func production(
        googleOAuth sdkConfiguration: AIChatSDKConfiguration.GoogleOAuth?
    ) -> AppEnvironment {
        let fallback = GoogleOAuthConfiguration(
            clientID: "322950785121-eg4r8f9k787iecdlnt3ike6as4el1flm.apps.googleusercontent.com",
            authorizationEndpoint: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
            tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!,
            userInfoEndpoint: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!,
            scopes: ["openid", "email", "profile"]
        )
        guard let sdkConfiguration else {
            return AppEnvironment(googleOAuth: fallback)
        }
        return AppEnvironment(googleOAuth: GoogleOAuthConfiguration(
            clientID: sdkConfiguration.clientID,
            authorizationEndpoint: sdkConfiguration.authorizationEndpoint,
            tokenEndpoint: sdkConfiguration.tokenEndpoint,
            userInfoEndpoint: sdkConfiguration.userInfoEndpoint,
            scopes: sdkConfiguration.scopes
        ))
    }
}
