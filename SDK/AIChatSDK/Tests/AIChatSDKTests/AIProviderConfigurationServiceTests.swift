import Foundation
import XCTest
@testable import AIChatSDK

final class AIProviderConfigurationServiceTests: XCTestCase {
    @MainActor
    func test_addDefaultProviderPersistsReusableDefault() {
        let store = InMemoryProviderConfigStore()
        let service = DefaultAIProviderConfigurationService(
            configStore: store,
            secureStore: InMemorySecureStore()
        )

        let configuration = service.addDefaultProvider()

        XCTAssertEqual(service.configurations, [configuration])
        XCTAssertEqual(configuration.baseURL.absoluteString, "http://localhost:11434/v1")
        XCTAssertEqual(configuration.models.map(\.id), ["llama3"])
    }

    @MainActor
    func test_credentialLifecycleIsOwnedByService() throws {
        let secureStore = InMemorySecureStore()
        let service = DefaultAIProviderConfigurationService(
            configStore: InMemoryProviderConfigStore(),
            secureStore: secureStore
        )
        let configuration = ProviderConfiguration(
            name: "Provider",
            baseURL: URL(string: "https://example.com/v1")!,
            requiresAPIKey: true
        )

        XCTAssertFalse(service.hasCredential(for: configuration))
        try service.saveCredential("secret", for: configuration)
        XCTAssertTrue(service.hasCredential(for: configuration))
        try service.deleteCredential(for: configuration)
        XCTAssertFalse(service.hasCredential(for: configuration))
    }

    @MainActor
    func test_refreshModelsUsesInjectedNetworkAndPersistsCapabilities() async throws {
        let url = URL(string: "https://api.openai.com/v1/models")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let networkClient = ProviderConfigurationMockNetworkClient(
            data: Data(#"{"data":[{"id":"gpt-4o"}]}"#.utf8),
            response: response
        )
        let store = InMemoryProviderConfigStore()
        let secureStore = InMemorySecureStore()
        let service = DefaultAIProviderConfigurationService(
            configStore: store,
            secureStore: secureStore,
            networkClient: networkClient
        )
        let configuration = ProviderConfiguration(
            name: "OpenAI",
            baseURL: URL(string: "https://api.openai.com/v1")!,
            requiresAPIKey: true
        )

        let refreshed = try await service.refreshModels(
            for: configuration,
            credential: "test-token"
        )

        XCTAssertEqual(refreshed.models.map(\.id), ["gpt-4o"])
        XCTAssertTrue(refreshed.supportsImages)
        XCTAssertNotNil(refreshed.modelsFetchedAt)
        XCTAssertEqual(store.configs, [refreshed])
        XCTAssertTrue(service.hasCredential(for: refreshed))
    }

    @MainActor
    func test_emptyModelResponseThrowsNoModelsWithoutPersistence() async throws {
        let url = URL(string: "https://example.com/v1/models")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let store = InMemoryProviderConfigStore()
        let service = DefaultAIProviderConfigurationService(
            configStore: store,
            secureStore: InMemorySecureStore(),
            networkClient: ProviderConfigurationMockNetworkClient(
                data: Data(#"{"data":[]}"#.utf8),
                response: response
            )
        )
        let configuration = ProviderConfiguration(
            name: "Empty",
            baseURL: URL(string: "https://example.com/v1")!,
            requiresAPIKey: false
        )

        do {
            _ = try await service.refreshModels(for: configuration, credential: nil)
            XCTFail("Expected noModels")
        } catch let error as AIProviderConfigurationError {
            XCTAssertEqual(error, .noModels)
        }
        XCTAssertTrue(store.configs.isEmpty)
    }
}

@MainActor
private final class InMemoryProviderConfigStore: ProviderConfigStore {
    private(set) var configs: [ProviderConfiguration] = []
    var onChange: (() -> Void)?

    func save(_ config: ProviderConfiguration) {
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
        } else {
            configs.append(config)
        }
        onChange?()
    }

    func delete(id: UUID) {
        configs.removeAll { $0.id == id }
        onChange?()
    }
}

private struct ProviderConfigurationMockNetworkClient: NetworkClient {
    let data: Data
    let response: HTTPURLResponse

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        (data, response)
    }

    func bytes(for request: URLRequest) async throws -> (NetworkByteStream, HTTPURLResponse) {
        let stream = NetworkByteStream { continuation in
            continuation.finish()
        }
        return (stream, response)
    }
}
