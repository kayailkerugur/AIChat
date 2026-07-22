import Foundation

public struct ChatRequest: Equatable, Sendable {
    public let messages: [ChatMessage]
    public let modelID: String

    public init(messages: [ChatMessage], modelID: String) {
        self.messages = messages
        self.modelID = modelID
    }
}

public struct TokenUsage: Equatable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

public enum AIStreamEvent: Equatable, Sendable {
    case textDelta(String)
    case usage(TokenUsage)
    case completed
}
