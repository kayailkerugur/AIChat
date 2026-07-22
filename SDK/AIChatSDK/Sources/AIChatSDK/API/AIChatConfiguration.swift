import Foundation

/// SDK-wide behavior that is independent from application lifecycle and UI
/// navigation.
public struct AIChatConfiguration: Equatable, Sendable {
    public var defaultConversationTitle: String

    public init(defaultConversationTitle: String = "Yeni Sohbet") {
        self.defaultConversationTitle = defaultConversationTitle
    }
}
