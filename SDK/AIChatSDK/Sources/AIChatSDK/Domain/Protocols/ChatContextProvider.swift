/// Supplies ephemeral messages that are sent to the AI provider but are not
/// displayed or persisted as part of the conversation.
///
/// Context providers allow host applications and SDK features to enrich a
/// request without coupling the chat pipeline to a concrete dependency.
@MainActor
public protocol ChatContextProvider: Sendable {
    func contextMessages() -> [ChatMessage]
}
