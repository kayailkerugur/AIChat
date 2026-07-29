import Foundation

/// Host-selected behavior for the SDK chat experience.
///
/// The mode is fixed by the integrating application. The SDK does not expose
/// a user-facing mode picker.
public enum AIChatMode: String, Codable, CaseIterable, Equatable, Sendable {
    /// Existing general-purpose conversation behavior.
    case standard

    /// Repository-aware conversation behavior. Repository access and UI are
    /// introduced separately; until then this value only expresses intent.
    case code
}

/// SDK-wide behavior that is independent from application lifecycle and UI
/// navigation.
public struct AIChatConfiguration: Equatable, Sendable {
    public var defaultConversationTitle: String
    public var mode: AIChatMode
    public var codeContextCharacterLimit: Int
    public var codeFileByteLimit: Int

    public init(
        defaultConversationTitle: String = "Yeni Sohbet",
        mode: AIChatMode = .standard,
        codeContextCharacterLimit: Int = 40_000,
        codeFileByteLimit: Int = 200_000
    ) {
        self.defaultConversationTitle = defaultConversationTitle
        self.mode = mode
        self.codeContextCharacterLimit = max(0, codeContextCharacterLimit)
        self.codeFileByteLimit = max(1, codeFileByteLimit)
    }
}
