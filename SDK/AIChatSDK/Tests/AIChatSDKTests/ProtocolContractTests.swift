import Foundation
import XCTest
@testable import AIChatSDK

@MainActor
final class ProtocolContractTests: XCTestCase {
    func testRegistryConveniencesUseRegisteredProviders() {
        let first = ProviderStub(
            id: "first",
            supportedModels: [AIModel(id: "model-a", displayName: "Model A", providerID: "first")]
        )
        let second = ProviderStub(
            id: "second",
            supportedModels: [AIModel(id: "model-b", displayName: "Model B", providerID: "second")]
        )
        let registry = RegistryStub(providers: [first, second])

        XCTAssertEqual(registry.allModels.map(\.id), ["model-a", "model-b"])
        XCTAssertEqual(registry.resolvedProvider(forID: "second")?.id, "second")
        XCTAssertEqual(registry.resolvedProvider(forID: "missing")?.id, "first")
    }

    func testSecureStoreContractRoundTripsValues() throws {
        let store = SecureStoreStub()

        try store.save("secret", forKey: "provider.test.api-key")
        XCTAssertEqual(try store.read(key: "provider.test.api-key"), "secret")

        try store.delete(key: "provider.test.api-key")
        XCTAssertNil(try store.read(key: "provider.test.api-key"))
    }
}

@MainActor
private final class ProviderStub: AIProvider {
    let id: String
    let supportedModels: [AIModel]
    let supportsImages = false

    init(id: String, supportedModels: [AIModel]) {
        self.id = id
        self.supportedModels = supportedModels
    }

    func refreshModels() async throws -> [AIModel] { supportedModels }

    func stream(request: ChatRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.completed)
            continuation.finish()
        }
    }

    func cancelCurrentRequest() {}
}

@MainActor
private final class RegistryStub: AIProviderRegistry {
    let providers: [any AIProvider]

    init(providers: [any AIProvider]) {
        self.providers = providers
    }

    func reload() {}

    func provider(withID id: String) -> (any AIProvider)? {
        providers.first { $0.id == id }
    }
}

@MainActor
private final class SecureStoreStub: SecureStore {
    private var values: [String: String] = [:]

    func read(key: String) throws -> String? { values[key] }

    func save(_ value: String, forKey key: String) throws {
        values[key] = value
    }

    func delete(key: String) throws {
        values[key] = nil
    }
}
