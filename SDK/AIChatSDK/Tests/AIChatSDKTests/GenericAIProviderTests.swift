import Foundation
import XCTest
@testable import AIChatSDK

@MainActor
final class GenericAIProviderTests: XCTestCase {
    func testRefreshModelsUsesAuthorizationAndDecodesModels() async throws {
        let network = ProviderNetworkClient(
            statusCode: 200,
            data: Data(#"{"data":[{"id":"model-a"}]}"#.utf8)
        )
        let secureStore = ProviderSecureStore(values: ["provider-key": "secret"])
        let config = ProviderConfig(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Provider",
            baseURL: URL(string: "https://example.com/v1")!,
            requiresAPIKey: true
        )
        secureStore.values[config.apiKeyStorageKey] = "secret"
        let provider = GenericAIProvider(
            config: config,
            secureStore: secureStore,
            networkClient: network
        )

        let models = try await provider.refreshModels()
        let request = await network.lastDataRequest

        XCTAssertEqual(models.map(\.id), ["model-a"])
        XCTAssertEqual(request?.url?.absoluteString, "https://example.com/v1/models")
        XCTAssertEqual(request?.httpMethod, "GET")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
    }

    func testRefreshModelsWithoutCredentialThrowsUnauthorizedBeforeNetwork() async {
        let network = ProviderNetworkClient(statusCode: 200, data: Data())
        let provider = GenericAIProvider(
            config: ProviderConfig(
                name: "Provider",
                baseURL: URL(string: "https://example.com/v1")!,
                requiresAPIKey: true
            ),
            secureStore: ProviderSecureStore(),
            networkClient: network
        )

        do {
            _ = try await provider.refreshModels()
            XCTFail("Expected unauthorized")
        } catch let error as AIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let capturedRequest = await network.lastDataRequest
        XCTAssertNil(capturedRequest)
    }

    func testQuotaResponseMapsToQuotaExceeded() async {
        let body = Data(#"{"error":{"message":"quota exceeded","code":"resource_exhausted"}}"#.utf8)
        let network = ProviderNetworkClient(statusCode: 429, data: body)
        let provider = GenericAIProvider(
            config: ProviderConfig(
                name: "Provider",
                baseURL: URL(string: "https://example.com/v1")!,
                requiresAPIKey: false
            ),
            secureStore: ProviderSecureStore(),
            networkClient: network
        )

        do {
            _ = try await provider.refreshModels()
            XCTFail("Expected quotaExceeded")
        } catch let error as AIError {
            XCTAssertEqual(error, .quotaExceeded)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStreamParsesTextUsageAndCompletionWithoutRealNetwork() async throws {
        let sse = """
        data: {"choices":[{"delta":{"content":"Hello"}}],"usage":null}

        data: {"choices":[],"usage":{"prompt_tokens":3,"completion_tokens":2}}

        data: [DONE]

        """
        let network = ProviderNetworkClient(
            statusCode: 200,
            data: Data(),
            streamBytes: Array(sse.utf8)
        )
        let provider = GenericAIProvider(
            config: ProviderConfig(
                name: "Provider",
                baseURL: URL(string: "https://example.com/v1")!,
                requiresAPIKey: false
            ),
            secureStore: ProviderSecureStore(),
            networkClient: network
        )

        var events: [AIStreamEvent] = []
        for try await event in provider.stream(request: ChatRequest(
            messages: [ChatMessage(role: .user, content: "Hi")],
            modelID: "model-a"
        )) {
            events.append(event)
        }
        let request = await network.lastStreamRequest

        XCTAssertEqual(events.first, .textDelta("Hello"))
        XCTAssertTrue(events.contains(.usage(TokenUsage(inputTokens: 3, outputTokens: 2))))
        XCTAssertEqual(request?.url?.absoluteString, "https://example.com/v1/chat/completions")
        XCTAssertEqual(request?.httpMethod, "POST")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
}

@MainActor
private final class ProviderSecureStore: SecureStore {
    var values: [String: String]

    init(values: [String: String] = [:]) {
        self.values = values
    }

    func read(key: String) throws -> String? { values[key] }
    func save(_ value: String, forKey key: String) throws { values[key] = value }
    func delete(key: String) throws { values[key] = nil }
}

private actor ProviderNetworkClient: NetworkClient {
    private let statusCode: Int
    private let responseData: Data
    private let streamBytes: [UInt8]

    private(set) var lastDataRequest: URLRequest?
    private(set) var lastStreamRequest: URLRequest?

    init(statusCode: Int, data: Data, streamBytes: [UInt8] = []) {
        self.statusCode = statusCode
        self.responseData = data
        self.streamBytes = streamBytes
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastDataRequest = request
        return (responseData, response(for: request))
    }

    func bytes(for request: URLRequest) async throws -> (NetworkByteStream, HTTPURLResponse) {
        lastStreamRequest = request
        let bytes = streamBytes
        let stream = NetworkByteStream { continuation in
            for byte in bytes {
                continuation.yield(byte)
            }
            continuation.finish()
        }
        return (stream, response(for: request))
    }

    private func response(for request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
