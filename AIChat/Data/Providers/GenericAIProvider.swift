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
    let supportsImages: Bool

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
        self.supportsImages = config.supportsImages
    }

    func refreshModels() async throws -> [AIModel] {
        var request = URLRequest(url: config.baseURL.appending(path: "models"))
        request.httpMethod = "GET"
        try applyAuthorization(to: &request)

        let (data, response) = try await urlSession.data(for: request)
        try validate(response, body: data)

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
                    try self.validate(response, body: nil)

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
        request.httpBody = try JSONEncoder().encode(ChatCompletionsRequest(
            from: chatRequest,
            supportsImages: supportsImages
        ))
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

    private func validate(_ response: URLResponse, body: Data?) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIError.malformedResponse
        }

        switch http.statusCode {
        case 200:
            return
        case 400, 401, 403:
            let error = providerError(from: body)
            logger.error("Generic provider auth/request rejected: HTTP \(http.statusCode)")
            if error?.isQuotaLike == true {
                throw AIError.quotaExceeded
            }
            if error?.isModelLike == true {
                throw AIError.modelUnavailable
            }
            if let message = error?.safeUserMessage {
                throw AIError.providerRejected(message: message)
            }
            throw AIError.unauthorized
        case 404:
            logger.error("Generic provider model or endpoint not found: HTTP 404")
            throw AIError.modelUnavailable
        case 429:
            let error = providerError(from: body)
            logger.notice("Generic provider rate limited: HTTP 429")
            if error?.isQuotaLike == true {
                throw AIError.quotaExceeded
            }
            if let message = error?.safeUserMessage {
                throw AIError.providerRejected(message: message)
            }
            throw AIError.rateLimited
        default:
            logger.error("Generic provider unexpected status: HTTP \(http.statusCode)")
            throw AIError.unknown(debugDescription: "HTTP \(http.statusCode)")
        }
    }

    private func providerError(from body: Data?) -> ProviderErrorPayload? {
        guard let body else { return nil }
        return try? JSONDecoder().decode(ProviderErrorPayload.self, from: body)
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
        let content: MessageContent
    }

    enum MessageContent: Encodable {
        case text(String)
        case parts([ContentPart])

        func encode(to encoder: Encoder) throws {
            switch self {
            case .text(let text):
                var container = encoder.singleValueContainer()
                try container.encode(text)
            case .parts(let parts):
                var container = encoder.singleValueContainer()
                try container.encode(parts)
            }
        }
    }

    struct ContentPart: Encodable {
        struct ImageURL: Encodable {
            let url: String
        }

        let type: String
        let text: String?
        let imageURL: ImageURL?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            if let text {
                try container.encode(text, forKey: .text)
            }
            if let imageURL {
                try container.encode(imageURL, forKey: .imageURL)
            }
        }

        static func text(_ value: String) -> ContentPart {
            ContentPart(type: "text", text: value, imageURL: nil)
        }

        static func image(_ attachment: ChatAttachment) -> ContentPart {
            ContentPart(
                type: "image_url",
                text: nil,
                imageURL: ImageURL(
                    url: "data:\(attachment.mimeType);base64,\(attachment.data.base64EncodedString())"
                )
            )
        }
    }

    let model: String
    let messages: [Message]
    let stream: Bool

    init(from request: ChatRequest, supportsImages: Bool) {
        self.model = request.modelID
        self.stream = true
        self.messages = request.messages.compactMap { message in
            let content = Self.content(from: message, supportsImages: supportsImages)
            guard content != nil else { return nil }
            return Message(
                role: message.role.rawValue,
                content: content!
            )
        }
    }

    private static func content(from message: ChatMessage, supportsImages: Bool) -> MessageContent? {
        guard !message.attachments.isEmpty else {
            return message.content.isEmpty ? nil : .text(message.content)
        }

        var parts: [ContentPart] = []
        if !message.content.isEmpty {
            parts.append(.text(message.content))
        }

        for attachment in message.attachments {
            switch attachment.kind {
            case .image:
                if supportsImages {
                    parts.append(.image(attachment))
                } else {
                    parts.append(.text("""
                    Attached image was not sent because this provider is configured without image support.
                    File: \(attachment.fileName)
                    MIME type: \(attachment.mimeType)
                    """))
                }
            case .document:
                if let text = attachment.extractedText, !text.isEmpty {
                    parts.append(.text("""
                    Document: \(attachment.fileName)

                    \(text)
                    """))
                } else {
                    parts.append(.text("""
                    Attached document could not be read as text.
                    File: \(attachment.fileName)
                    MIME type: \(attachment.mimeType)
                    """))
                }
            }
        }

        return parts.isEmpty ? nil : .parts(parts)
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

private struct ProviderErrorPayload: Decodable {

    struct ErrorDetails: Decodable {
        let message: String?
        let type: String?
        let code: String?
        let status: String?
    }

    let error: ErrorDetails?

    private var searchableText: String {
        [
            error?.message,
            error?.type,
            error?.code,
            error?.status,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    }

    var isQuotaLike: Bool {
        let text = searchableText
        return text.contains("quota")
            || text.contains("billing")
            || text.contains("credit")
            || text.contains("insufficient")
            || text.contains("resource_exhausted")
    }

    var isModelLike: Bool {
        let text = searchableText
        return text.contains("model")
            && (text.contains("not found") || text.contains("unavailable"))
    }

    var safeUserMessage: String? {
        guard let message = error?.message else { return nil }
        let collapsed = message
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(180))
    }
}
