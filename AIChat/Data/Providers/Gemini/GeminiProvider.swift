//
//  GeminiProvider.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//
//

import Foundation
import os

final class GeminiProvider: AIProvider {
    func refreshModels() async throws -> [AIModel] {
        return []
    }
    // MARK: - AIProvider

    let id = "gemini"

    /// Model list may need refreshing as Google ships new versions —
    /// display names are ours, ids are Google's.
    let supportedModels: [AIModel] = [
        AIModel(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash", providerID: "gemini"),
        AIModel(id: "gemini-2.5-flash-lite", displayName: "Gemini 2.5 Flash Lite", providerID: "gemini"),
    ]

    // MARK: - Dependencies

    private let configuration: AppEnvironment.GeminiConfiguration
    private let secureStore: SecureStore
    private let urlSession: URLSession
    private let logger = AppLogger.ai

    private var currentTask: Task<Void, Never>?

    init(
        configuration: AppEnvironment.GeminiConfiguration,
        secureStore: SecureStore,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.secureStore = secureStore
        self.urlSession = urlSession
    }

    // MARK: - Streaming

    func stream(request: ChatRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try self.makeURLRequest(for: request)
                    let (bytes, response) = try await self.urlSession.bytes(for: urlRequest)
                    try self.validate(response)

                    // NOTE: we deliberately do NOT use `bytes.lines` here.
                    // AsyncLineSequence skips empty lines — but empty lines
                    // are exactly what delimit SSE events. We split lines
                    // manually so the tested SSEEventParser sees them.
                    var parser = SSEEventParser()
                    var lineBuffer: [UInt8] = []

                    func process(lineBytes: [UInt8]) throws {
                        var line = String(decoding: lineBytes, as: UTF8.self)
                        if line.hasSuffix("\r") { line.removeLast() }
                        if let payload = parser.feed(line: line) {
                            try self.emit(payload: payload, to: continuation)
                        }
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
                    self.logger.error("Gemini network error: \(error.code.rawValue)")
                    continuation.finish(throwing: AIError.network)
                } catch {
                    self.logger.error("Gemini unexpected error: \(String(describing: type(of: error)))")
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
        guard let apiKey = try? secureStore.read(.geminiAPIKey),
              !apiKey.isEmpty
        else {
            throw AIError.unauthorized
        }

        var request = URLRequest(url: configuration.streamURL(forModel: chatRequest.modelID))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(GeminiRequest(from: chatRequest))
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIError.malformedResponse
        }
        // Status code only — never read/log the error body.
        switch http.statusCode {
        case 200:
            return
        case 400, 401, 403:
            // Gemini returns 400 INVALID_ARGUMENT for invalid API keys.
            logger.error("Gemini auth/request rejected: HTTP \(http.statusCode)")
            throw AIError.unauthorized
        case 404:
            logger.error("Gemini model not found: HTTP 404")
            throw AIError.modelUnavailable
        case 429:
            logger.notice("Gemini rate limited: HTTP 429")
            throw AIError.rateLimited
        default:
            logger.error("Gemini unexpected status: HTTP \(http.statusCode)")
            throw AIError.unknown(debugDescription: "HTTP \(http.statusCode)")
        }
    }

    // MARK: - Chunk handling

    private func emit(
        payload: String,
        to continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation
    ) throws {
        guard let data = payload.data(using: .utf8) else {
            throw AIError.malformedResponse
        }
        let chunk: StreamChunk
        do {
            chunk = try JSONDecoder().decode(StreamChunk.self, from: data)
        } catch {
            logger.error("Gemini chunk decode failed")
            throw AIError.malformedResponse
        }

        let text = chunk.candidates?
            .first?.content?.parts?
            .compactMap(\.text)
            .joined() ?? ""

        if !text.isEmpty {
            continuation.yield(.textDelta(text))
        }

        if let usage = chunk.usageMetadata,
           let input = usage.promptTokenCount,
           let output = usage.candidatesTokenCount {
            continuation.yield(.usage(TokenUsage(
                inputTokens: input,
                outputTokens: output
            )))
        }
    }
}

// MARK: - Wire DTOs (never leave this file)

/// Request body for :streamGenerateContent.
private struct GeminiRequest: Encodable {

    struct Part: Encodable {
        let text: String
    }

    struct Content: Encodable {
        let role: String // "user" | "model" — Gemini has no "assistant"
        let parts: [Part]
    }

    struct SystemInstruction: Encodable {
        let parts: [Part]
    }

    let contents: [Content]
    let systemInstruction: SystemInstruction?

    init(from request: ChatRequest) {
        var systemTexts: [String] = []
        var contents: [Content] = []

        for message in request.messages {
            switch message.role {
            case .system:
                // Gemini takes system prompts as a separate field,
                // not as a "system" role inside contents.
                systemTexts.append(message.content)
            case .user:
                contents.append(Content(
                    role: "user",
                    parts: [Part(text: message.content)]
                ))
            case .assistant:
                // Skip empty placeholders (streaming stub, cancelled-empty).
                guard !message.content.isEmpty else { continue }
                contents.append(Content(
                    role: "model",
                    parts: [Part(text: message.content)]
                ))
            }
        }

        self.contents = contents
        self.systemInstruction = systemTexts.isEmpty
            ? nil
            : SystemInstruction(parts: systemTexts.map { Part(text: $0) })
    }
}

/// One SSE data payload from :streamGenerateContent.
/// Everything optional — chunks vary (delta-only, usage-only, final).
private struct StreamChunk: Decodable {

    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]?
        }
        let content: Content?
        let finishReason: String?
    }

    struct UsageMetadata: Decodable {
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
    }

    let candidates: [Candidate]?
    let usageMetadata: UsageMetadata?
}
