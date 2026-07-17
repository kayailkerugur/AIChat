import SwiftUI

/// Host applications use this value to brand and configure the SDK UI.
public struct AIChatSDKConfiguration: Sendable {
    public struct GoogleOAuth: Sendable {
        public var clientID: String
        public var authorizationEndpoint: URL
        public var tokenEndpoint: URL
        public var userInfoEndpoint: URL
        public var scopes: [String]

        public init(
            clientID: String,
            authorizationEndpoint: URL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
            tokenEndpoint: URL = URL(string: "https://oauth2.googleapis.com/token")!,
            userInfoEndpoint: URL = URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!,
            scopes: [String] = ["openid", "email", "profile"]
        ) {
            self.clientID = clientID
            self.authorizationEndpoint = authorizationEndpoint
            self.tokenEndpoint = tokenEndpoint
            self.userInfoEndpoint = userInfoEndpoint
            self.scopes = scopes
        }

        /// Register this value under the host target's URL Types.
        public var callbackURLScheme: String {
            let suffix = ".apps.googleusercontent.com"
            guard clientID.hasSuffix(suffix) else { return clientID }
            return "com.googleusercontent.apps.\(clientID.dropLast(suffix.count))"
        }

        public var redirectURI: String {
            "\(callbackURLScheme):/oauth2redirect"
        }
    }

    public struct Branding: Sendable {
        public var applicationName: String
        public var accentColor: Color
        public var logoSystemName: String?
        public var loginSubtitle: String

        public init(
            applicationName: String = "AI Chat",
            accentColor: Color = .accentColor,
            logoSystemName: String? = nil,
            loginSubtitle: String = "Devam etmek için giriş yapın"
        ) {
            self.applicationName = applicationName
            self.accentColor = accentColor
            self.logoSystemName = logoSystemName
            self.loginSubtitle = loginSubtitle
        }
    }

    public var branding: Branding
    public var licenseKey: String?
    public var googleOAuth: GoogleOAuth?

    public init(
        branding: Branding = .init(),
        licenseKey: String? = nil,
        googleOAuth: GoogleOAuth? = nil
    ) {
        self.branding = branding
        self.licenseKey = licenseKey
        self.googleOAuth = googleOAuth
    }
}

private struct AIChatSDKConfigurationKey: EnvironmentKey {
    static let defaultValue = AIChatSDKConfiguration()
}

extension EnvironmentValues {
    var aiChatSDKConfiguration: AIChatSDKConfiguration {
        get { self[AIChatSDKConfigurationKey.self] }
        set { self[AIChatSDKConfigurationKey.self] = newValue }
    }
}
