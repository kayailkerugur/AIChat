//
//  OAuthService.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 7.07.2026.
//
//  Real AuthService: OAuth 2.0 Authorization Code + PKCE against
//  Google, through ASWebAuthenticationSession (system browser session,
//  never an embedded web view — the app can never see the password).
//
//  Flow (spec §6.1):
//    1. generate PKCE pair + random state
//    2. open authorization endpoint in ASWebAuthenticationSession
//    3. user signs in at Google
//    4. callback URL arrives → validate state, extract code
//    5. exchange code + PKCE verifier for tokens
//    6. tokens → Keychain (SecureStore)
//    7. userinfo → AuthSession → publish via sessionUpdates
//
//  Storage split:
//    - access/refresh token + expiry → Keychain ONLY
//    - display name/email/user id   → UserDefaults (profile cache;
//      not credentials — lets restore work without a network call)
//

import Foundation
import AIChatSDK
import AuthenticationServices
import AppKit
import os

@MainActor
final class OAuthService: AuthService {

    // MARK: - AuthService state

    private(set) var currentSession: AuthSession?

    var sessionUpdates: AsyncStream<AuthSession?> {
        AsyncStream { continuation in
            self.continuations.append(continuation)
            continuation.yield(self.currentSession)
        }
    }
    private var continuations: [AsyncStream<AuthSession?>.Continuation] = []

    // MARK: - Dependencies

    private let configuration: AppEnvironment.GoogleOAuthConfiguration
    private let secureStore: SecureStore
    private let urlSession: URLSession
    private let logger = AppLogger.auth

    private var webAuthSession: ASWebAuthenticationSession?
    private let presentationContext = WebAuthPresentationContext()

    init(
        configuration: AppEnvironment.GoogleOAuthConfiguration,
        secureStore: SecureStore,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.secureStore = secureStore
        self.urlSession = urlSession
    }

    // MARK: - Login

    @discardableResult
    func login() async throws -> AuthSession {
        let pkce = PKCEGenerator.makePair()
        let state = Self.randomStateToken()

        var components = URLComponents(
            url: configuration.authorizationEndpoint,
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: pkce.method),
        ]

        let callbackURL = try await startWebAuthentication(url: components.url!)

        // Security gate: state must round-trip unchanged (CSRF protection).
        let code = try Self.authorizationCode(
            fromCallback: callbackURL,
            expectedState: state
        )

        let tokens = try await exchangeCode(code, verifier: pkce.verifier)
        try persist(tokens)

        let profile = try await fetchUserInfo(accessToken: tokens.accessToken)
        ProfileCache.save(profile)

        let session = AuthSession(
            userID: profile.sub,
            displayName: profile.name,
            email: profile.email,
            providerID: "google",
            expiresAt: tokens.expiryDate
        )
        publish(session)
        logger.notice("OAuth login succeeded") // never log tokens/codes
        return session
    }

    // MARK: - Restore & refresh

    @discardableResult
    func restoreSession() async throws -> AuthSession {
        let accessToken: String?
        do {
            accessToken = try secureStore.read(.oauthAccessToken)
        } catch {
            throw AuthError.secureStorage
        }
        guard var accessToken else {
            throw AuthError.noStoredSession
        }

        var expiresAt = storedExpiry()

        // 60s safety margin: don't hand the UI a token about to die.
        let needsRefresh = (expiresAt ?? .distantPast) <= Date().addingTimeInterval(60)
        if needsRefresh {
            guard let refreshToken = ((try? secureStore.read(.oauthRefreshToken)) ?? nil),
                  !refreshToken.isEmpty
            else {
                clearStoredCredentials()
                throw AuthError.sessionExpired
            }

            do {
                let refreshed = try await refreshAccessToken(refreshToken: refreshToken)
                try persist(refreshed, existingRefreshToken: refreshToken)
                accessToken = refreshed.accessToken
                expiresAt = refreshed.expiryDate
                logger.notice("OAuth token refreshed")
            } catch AuthError.unauthorized {
                // Refresh token revoked/expired → the session is truly over.
                clearStoredCredentials()
                throw AuthError.sessionExpired
            }
            // Network errors propagate as-is: temporary offline should
            // not destroy a valid stored session.
        }

        // Profile from cache; fetch once if the cache was ever lost.
        let profile: UserInfo
        if let cached = ProfileCache.load() {
            profile = cached
        } else {
            profile = try await fetchUserInfo(accessToken: accessToken)
            ProfileCache.save(profile)
        }

        let session = AuthSession(
            userID: profile.sub,
            displayName: profile.name,
            email: profile.email,
            providerID: "google",
            expiresAt: expiresAt
        )
        publish(session)
        return session
    }

    // MARK: - Logout

    func logout() async {
        webAuthSession?.cancel()
        webAuthSession = nil
        clearStoredCredentials()
        ProfileCache.clear()
        publish(nil)
        logger.notice("Logged out; local credentials cleared")
    }

    // MARK: - Web authentication

    private func startWebAuthentication(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: configuration.reversedClientID
            ) { callbackURL, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.cancelledByUser)
                    } else {
                        continuation.resume(throwing: AuthError.unknown(
                            debugDescription: String(describing: error)
                        ))
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: AuthError.invalidCallback)
                    return
                }
                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = presentationContext
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session

            if !session.start() {
                continuation.resume(throwing: AuthError.unknown(
                    debugDescription: "ASWebAuthenticationSession failed to start"
                ))
            }
        }
    }

    // MARK: - Callback parsing (pure — unit tested)

    /// Validates the OAuth callback and extracts the authorization code.
    /// Throws:
    /// - `.cancelledByUser`  when Google reports access_denied
    /// - `.unauthorized`     for any other provider error
    /// - `.invalidCallback`  on state mismatch or missing code
    nonisolated static func authorizationCode(
        fromCallback url: URL,
        expectedState: String
    ) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { throw AuthError.invalidCallback }

        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        if let providerError = value("error") {
            throw providerError == "access_denied"
                ? AuthError.cancelledByUser
                : AuthError.unauthorized
        }

        guard let state = value("state"), state == expectedState else {
            // Missing OR mismatched state → possible CSRF, reject hard.
            throw AuthError.invalidCallback
        }

        guard let code = value("code"), !code.isEmpty else {
            throw AuthError.invalidCallback
        }

        return code
    }

    nonisolated static func randomStateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            var generator = SystemRandomNumberGenerator()
            bytes = (0..<16).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        }
        return PKCEGenerator.base64URLEncode(Data(bytes))
    }

    // MARK: - Token endpoint

    private func exchangeCode(_ code: String, verifier: String) async throws -> TokenResponse {
        try await performTokenRequest(form: [
            "client_id": configuration.clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": configuration.redirectURI,
        ])
    }

    private func refreshAccessToken(refreshToken: String) async throws -> TokenResponse {
        try await performTokenRequest(form: [
            "client_id": configuration.clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ])
    }

    private func performTokenRequest(form: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = Self.formEncodedBody(form)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw AuthError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.network
        }

        switch http.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(TokenResponse.self, from: data)
            } catch {
                logger.error("Token response decode failed")
                throw AuthError.unknown(debugDescription: "token decode")
            }
        case 400, 401:
            // invalid_grant / invalid credentials. Body is NOT logged.
            logger.error("Token endpoint rejected request: HTTP \(http.statusCode)")
            throw AuthError.unauthorized
        default:
            logger.error("Token endpoint unexpected status: HTTP \(http.statusCode)")
            throw AuthError.unknown(debugDescription: "HTTP \(http.statusCode)")
        }
    }

    nonisolated static func formEncodedBody(_ form: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = form
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .sorted() // deterministic for tests
            .joined(separator: "&")
        return Data(encoded.utf8)
    }

    // MARK: - User info

    private func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        var request = URLRequest(url: configuration.userInfoEndpoint)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw AuthError.network
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            logger.error("userinfo request failed")
            throw AuthError.unauthorized
        }
        guard let info = try? JSONDecoder().decode(UserInfo.self, from: data) else {
            throw AuthError.unknown(debugDescription: "userinfo decode")
        }
        return info
    }

    // MARK: - Persistence helpers

    private func persist(
        _ tokens: TokenResponse,
        existingRefreshToken: String? = nil
    ) throws {
        do {
            try secureStore.save(tokens.accessToken, for: .oauthAccessToken)
            try secureStore.save(
                String(tokens.expiryDate.timeIntervalSince1970),
                for: .oauthTokenExpiry
            )
            // Google often omits refresh_token on refresh responses —
            // keep the existing one in that case.
            if let refresh = tokens.refreshToken ?? existingRefreshToken {
                try secureStore.save(refresh, for: .oauthRefreshToken)
            }
        } catch {
            logger.error("Token persist failed")
            throw AuthError.secureStorage
        }
    }

    private func storedExpiry() -> Date? {
        guard let raw = ((try? secureStore.read(.oauthTokenExpiry)) ?? nil),
              let interval = TimeInterval(raw)
        else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    private func clearStoredCredentials() {
        try? secureStore.delete(.oauthAccessToken)
        try? secureStore.delete(.oauthRefreshToken)
        try? secureStore.delete(.oauthTokenExpiry)
    }

    private func publish(_ session: AuthSession?) {
        currentSession = session
        for continuation in continuations {
            continuation.yield(session)
        }
    }
}

// MARK: - Presentation context (macOS window anchor)

private final class WebAuthPresentationContext: NSObject,
    ASWebAuthenticationPresentationContextProviding {

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow
            ?? NSApplication.shared.windows.first
            ?? ASPresentationAnchor()
    }
}

// MARK: - Wire DTOs (never leave this file)

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }

    var expiryDate: Date {
        Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}

struct UserInfo: Decodable {
    let sub: String
    let name: String?
    let email: String?
}

// MARK: - Profile cache (non-secret identity data)

/// Display name / email / user id are identity data, not credentials —
/// UserDefaults is appropriate and lets session restore work offline.
/// Tokens NEVER go here.
enum ProfileCache {

    private static let userIDKey = "auth.profile.userID"
    private static let nameKey = "auth.profile.name"
    private static let emailKey = "auth.profile.email"

    static func save(_ info: UserInfo) {
        let defaults = UserDefaults.standard
        defaults.set(info.sub, forKey: userIDKey)
        defaults.set(info.name, forKey: nameKey)
        defaults.set(info.email, forKey: emailKey)
    }

    static func load() -> UserInfo? {
        let defaults = UserDefaults.standard
        guard let sub = defaults.string(forKey: userIDKey) else { return nil }
        return UserInfo(
            sub: sub,
            name: defaults.string(forKey: nameKey),
            email: defaults.string(forKey: emailKey)
        )
    }

    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: userIDKey)
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: emailKey)
    }
}
