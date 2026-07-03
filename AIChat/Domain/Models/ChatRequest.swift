//
//  ChatRequest.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Domain/Models
//
//  The provider-agnostic request/response vocabulary.
//  Every provider implementation translates between these types and
//  its own wire format — the rest of the app never sees DTOs.
//

import Foundation

/// What the app asks a provider to do.
struct ChatRequest: Equatable {
    /// Full conversation context, oldest first. Providers read role+content.
    let messages: [ChatMessage]
    /// Which model to use. Must be one of the provider's supportedModels.
    let modelID: String

    init(messages: [ChatMessage], modelID: String) {
        self.messages = messages
        self.modelID = modelID
    }
}

/// Token accounting reported by providers that support it.
struct TokenUsage: Equatable {
    let inputTokens: Int
    let outputTokens: Int
}

/// Common streaming events. Provider-specific chunk formats (SSE lines,
/// JSON fragments…) are parsed inside the provider and surfaced as these.
///
/// Design note: there is intentionally NO `.failure` case here.
/// Failures travel as thrown `AIError` through the AsyncThrowingStream,
/// which guarantees a failed stream also *terminates* — one less
/// invalid state ("failure event followed by more deltas") to handle.
enum AIStreamEvent: Equatable {
    /// A new fragment of assistant text. Append to the message content.
    case textDelta(String)
    /// Optional usage info, typically arrives once near the end.
    case usage(TokenUsage)
    /// The provider finished successfully. Always the last event.
    case completed
}
