import Foundation
import XCTest
@testable import AIChatSDK

final class NetworkClientTests: XCTestCase {
    func testMockNetworkClientReturnsConfiguredResponseWithoutNetworkAccess() async throws {
        let url = URL(string: "https://example.invalid/models")!
        let expectedData = Data(#"{"data":[]}"#.utf8)
        let expectedResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let client = MockNetworkClient(data: expectedData, response: expectedResponse)

        let (data, response) = try await client.data(for: URLRequest(url: url))

        XCTAssertEqual(data, expectedData)
        XCTAssertEqual(response.statusCode, 200)
    }
}

private struct MockNetworkClient: NetworkClient {
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
