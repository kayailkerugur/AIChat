import Foundation

public typealias NetworkByteStream = AsyncThrowingStream<UInt8, Error>

public protocol NetworkClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func bytes(for request: URLRequest) async throws -> (NetworkByteStream, HTTPURLResponse)
}

public final class URLSessionNetworkClient: NetworkClient, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, response)
    }

    public func bytes(for request: URLRequest) async throws -> (NetworkByteStream, HTTPURLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let stream = NetworkByteStream { continuation in
            let forwardingTask = Task {
                do {
                    for try await byte in bytes {
                        try Task.checkCancellation()
                        continuation.yield(byte)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                forwardingTask.cancel()
            }
        }

        return (stream, response)
    }
}
