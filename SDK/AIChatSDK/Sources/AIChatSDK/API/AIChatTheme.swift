import SwiftUI

/// Semantic colors used by the reusable chat and voice interfaces.
///
/// System materials and hierarchical foreground styles intentionally remain
/// under macOS control so accessibility, dark mode and contrast behavior are
/// preserved.
public struct AIChatTheme: Sendable {
    public var accentColor: Color
    public var warningColor: Color
    public var recordingColor: Color
    public var waitingColor: Color
    public var speakingColor: Color
    public var titleFont: Font
    public var voiceTitleFont: Font
    public var bodyFont: Font
    public var supportingFont: Font
    public var captionFont: Font
    public var codeFont: Font

    public init(
        accentColor: Color = .accentColor,
        warningColor: Color = .yellow,
        recordingColor: Color = .red,
        waitingColor: Color = .orange,
        speakingColor: Color = .green,
        titleFont: Font = .title3,
        voiceTitleFont: Font = .title2.bold(),
        bodyFont: Font = .body,
        supportingFont: Font = .callout,
        captionFont: Font = .caption,
        codeFont: Font = .system(.callout, design: .monospaced)
    ) {
        self.accentColor = accentColor
        self.warningColor = warningColor
        self.recordingColor = recordingColor
        self.waitingColor = waitingColor
        self.speakingColor = speakingColor
        self.titleFont = titleFont
        self.voiceTitleFont = voiceTitleFont
        self.bodyFont = bodyFont
        self.supportingFont = supportingFont
        self.captionFont = captionFont
        self.codeFont = codeFont
    }

    public static let `default` = AIChatTheme()
}

private struct AIChatThemeKey: EnvironmentKey {
    static let defaultValue = AIChatTheme.default
}

public extension EnvironmentValues {
    var aiChatTheme: AIChatTheme {
        get { self[AIChatThemeKey.self] }
        set { self[AIChatThemeKey.self] = newValue }
    }
}

public extension View {
    func aiChatTheme(_ theme: AIChatTheme) -> some View {
        environment(\.aiChatTheme, theme)
    }
}
