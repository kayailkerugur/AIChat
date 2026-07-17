import SwiftUI
import Testing
@testable import AIChatSDK

@MainActor
struct AIChatSDKPublicAPITests {
    @Test func configurationAcceptsHostBranding() {
        let branding = AIChatSDKConfiguration.Branding(
            applicationName: "Host Chat",
            accentColor: .purple,
            logoSystemName: "sparkles",
            loginSubtitle: "Welcome"
        )
        let configuration = AIChatSDKConfiguration(
            branding: branding,
            licenseKey: "test-license"
        )

        #expect(configuration.branding.applicationName == "Host Chat")
        #expect(configuration.branding.logoSystemName == "sparkles")
        #expect(configuration.branding.loginSubtitle == "Welcome")
        #expect(configuration.licenseKey == "test-license")
    }

    @Test func defaultValidatorAllowsDevelopmentIntegration() async {
        let validator = AllowAllAIChatSDKLicenseValidator()
        #expect(await validator.validate(licenseKey: nil))
    }

    @Test func invalidLicenseHasStablePublicError() {
        #expect(AIChatSDKError.invalidLicense.errorDescription != nil)
    }

    @Test func googleOAuthDerivesCallbackSchemeFromClientID() {
        let oauth = AIChatSDKConfiguration.GoogleOAuth(
            clientID: "123-example.apps.googleusercontent.com"
        )
        #expect(oauth.callbackURLScheme == "com.googleusercontent.apps.123-example")
        #expect(oauth.redirectURI == "com.googleusercontent.apps.123-example:/oauth2redirect")
    }
}
