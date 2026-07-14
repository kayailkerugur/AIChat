//
//  AIProvider.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Domain/Protocols
//
//  The provider contract from the assignment spec. ViewModels and
//  use cases depend on this protocol only; OpenAI/Anthropic/Mock
//  implementations live behind it in the Data layer.
//

import Foundation

protocol AIProvider: AnyObject {
    /// Stable identifier, e.g. "openai", "mock". Stored on Conversation.providerID.
    var id: String { get }

    /// Models this provider can serve. Synchronous — reads the cached
    /// list (fetched at registration time), so pickers and fallback
    /// logic never await the network.
    var supportedModels: [AIModel] { get }

    /// Whether this provider/model family can receive image attachments
    /// through OpenAI-compatible multimodal content parts.
    var supportsImages: Bool { get }

    /// Re-fetches the model list from the provider (GET /models on
    /// OpenAI-compatible endpoints) and refreshes the cache. Called
    /// when a provider is registered — doubling as a connectivity and
    /// credential check — and from a "refresh models" action in Settings.
    @discardableResult
    func refreshModels() async throws -> [AIModel]

    /// Streams the assistant response for the given request.
    ///
    /// Contract:
    /// - Emits zero or more `.textDelta` / `.usage` events.
    /// - Ends with `.completed` on success, or finishes throwing `AIError`.
    /// - Cancelling the consuming Task stops the stream; providers must
    ///   also stop network work (check `Task.isCancelled` / use URLSession task).
    func stream(request: ChatRequest) -> AsyncThrowingStream<AIStreamEvent, Error>

    /// Explicit cancel hook (spec requirement). Stops the in-flight request,
    /// if any. Consumers may also simply cancel their Task — both paths
    /// must leave the provider in a clean state.
    func cancelCurrentRequest()
}
