//
//  GenericAIProvider.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 9.07.2026.
//

import Foundation
import os

final class GenericAIProvider: AIProvider {

    let id: String
    let supportedModels: [AIModel]

    private let config: ProviderConfig
    private let secureStore: SecureStore
    private let urlSession: URLSession
    private let logger = AppLogger.ai

    private var currentTask: Task<Void, Never>?

    init(
        config: ProviderConfig,
        secureStore: SecureStore,
        urlSession: URLSession = .shared
    ) {
        self.config = config
        self.secureStore = secureStore
        self.urlSession = urlSession
        self.id = config.providerID
        self.supportedModels = config.asAIModels
    }

    func refreshModels() async throws -> [AIModel] {
        var request = URLRequest(url: config.baseURL.appending(path: "models"))
        request.httpMethod = "GET"
        try applyAuthorization(to: &request)

        let (data, response) = try await urlSession.data(for: request)
        try validate(response)

        do {
            let payload = try JSONDecoder().decode(ModelsResponse.self, from: data)
            return payload.data.map {
                AIModel(
                    id: $0.id,
                    displayName: $0.id,
                    providerID: config.providerID
                )
            }
        } catch {
            logger.error("Generic provider models decode failed")
            throw AIError.malformedResponse
        }
    }

    func stream(request: ChatRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    let urlRequest = try self.makeURLRequest(for: request)
                    let (bytes, response) = try await self.urlSession.bytes(for: urlRequest)
                    try self.validate(response)

                    var parser = SSEEventParser()
                    var lineBuffer: [UInt8] = []

                    @MainActor
                    func process(lineBytes: [UInt8]) throws {
                        var line = String(decoding: lineBytes, as: UTF8.self)
                        if line.hasSuffix("\r") { line.removeLast() }
                        guard let payload = parser.feed(line: line) else { return }
                        try self.emit(payload: payload, to: continuation)
                    }

                    for try await byte in bytes {
                        try Task.checkCancellation()
                        if byte == UInt8(ascii: "\n") {
                            try process(lineBytes: lineBuffer)
                            lineBuffer.removeAll(keepingCapacity: true)
                        } else {
                            lineBuffer.append(byte)
                        }
                    }

                    if !lineBuffer.isEmpty {
                        try process(lineBytes: lineBuffer)
                    }
                    if let payload = parser.flushPending() {
                        try self.emit(payload: payload, to: continuation)
                    }

                    continuation.yield(.completed)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AIError.cancelled)
                } catch let error as AIError {
                    continuation.finish(throwing: error)
                } catch let error as URLError where error.code == .cancelled {
                    continuation.finish(throwing: AIError.cancelled)
                } catch let error as URLError {
                    self.logger.error("Generic provider network error: \(error.code.rawValue)")
                    continuation.finish(throwing: AIError.network)
                } catch {
                    self.logger.error("Generic provider unexpected error")
                    continuation.finish(throwing: AIError.unknown(
                        debugDescription: String(describing: error)
                    ))
                }
            }

            self.currentTask = task
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Request building

    private func makeURLRequest(for chatRequest: ChatRequest) throws -> URLRequest {
        var request = URLRequest(url: config.baseURL
            .appending(path: "chat")
            .appending(path: "completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatCompletionsRequest(from: chatRequest))
        try applyAuthorization(to: &request)
        return request
    }

    private func applyAuthorization(to request: inout URLRequest) throws {
        guard config.requiresAPIKey else { return }

        guard let apiKey = try? secureStore.read(key: config.apiKeyStorageKey),
              !apiKey.isEmpty
        else {
            throw AIError.unauthorized
        }

        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIError.malformedResponse
        }

        switch http.statusCode {
        case 200:
            return
        case 400, 401, 403:
            logger.error("Generic provider auth/request rejected: HTTP \(http.statusCode)")
            throw AIError.unauthorized
        case 404:
            logger.error("Generic provider model or endpoint not found: HTTP 404")
            throw AIError.modelUnavailable
        case 429:
            logger.notice("Generic provider rate limited: HTTP 429")
            throw AIError.rateLimited
        default:
            logger.error("Generic provider unexpected status: HTTP \(http.statusCode)")
            throw AIError.unknown(debugDescription: "HTTP \(http.statusCode)")
        }
    }

    // MARK: - Chunk handling

    private func emit(
        payload: String,
        to continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation
    ) throws {
        if payload == "[DONE]" {
            continuation.yield(.completed)
            return
        }

        guard let data = payload.data(using: .utf8) else {
            throw AIError.malformedResponse
        }

        let chunk: ChatCompletionsChunk
        do {
            chunk = try JSONDecoder().decode(ChatCompletionsChunk.self, from: data)
        } catch {
            logger.error("Generic provider chunk decode failed")
            throw AIError.malformedResponse
        }

        for choice in chunk.choices {
            if let text = choice.delta.content, !text.isEmpty {
                continuation.yield(.textDelta(text))
            }
        }

        if let usage = chunk.usage,
           let input = usage.promptTokens,
           let output = usage.completionTokens {
            continuation.yield(.usage(TokenUsage(
                inputTokens: input,
                outputTokens: output
            )))
        }
    }
}

// MARK: - Wire DTOs

private struct ChatCompletionsRequest: Encodable {

    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let stream: Bool

    init(from request: ChatRequest) {
        self.model = request.modelID
        self.stream = true
        self.messages = request.messages.compactMap { message in
            guard !message.content.isEmpty else { return nil }
            return Message(
                role: message.role.rawValue,
                content: message.content
            )
        }
    }
}

private struct ChatCompletionsChunk: Decodable {

    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }

        let delta: Delta
    }

    struct Usage: Decodable {
        let promptTokens: Int?
        let completionTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
        }
    }

    let choices: [Choice]
    let usage: Usage?
}

private struct ModelsResponse: Decodable {

    struct Model: Decodable {
        let id: String
    }

    let data: [Model]
}
