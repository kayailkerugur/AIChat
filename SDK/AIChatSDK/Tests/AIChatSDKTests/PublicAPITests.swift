import XCTest
import AIChatSDK
import SwiftUI

final class PublicAPITests: XCTestCase {
    func test_providerConfigurationUsesExistingCodableModel() throws {
        let configuration = ProviderConfiguration(
            name: "Public API Provider",
            baseURL: URL(string: "https://example.com/v1")!,
            requiresAPIKey: true
        )

        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(ProviderConfiguration.self, from: data)

        XCTAssertEqual(decoded, configuration)
        XCTAssertTrue(configuration.apiKeyStorageKey.hasPrefix("provider."))
    }

    func test_aiChatErrorPreservesExistingErrorCases() {
        let error: AIChatError = .unauthorized

        XCTAssertEqual(error, AIError.unauthorized)
    }

    @MainActor
    func test_themeSupportsSemanticColorConfiguration() {
        let theme = AIChatTheme(
            accentColor: .purple,
            warningColor: .pink,
            recordingColor: .brown,
            waitingColor: .cyan,
            speakingColor: .mint
        )

        _ = EmptyView().aiChatTheme(theme)
    }
}
