import SwiftUI

/// Images supplied by the host application for reusable SDK interfaces.
///
/// A nil logo preserves the SDK's existing layout. The default empty-state
/// image is the same SF Symbol used by the original chat interface.
public struct AIChatBranding: Sendable {
    public var logo: Image?
    public var emptyStateImage: Image

    public init(
        logo: Image? = nil,
        emptyStateImage: Image = Image(
            systemName: "bubble.left.and.text.bubble.right"
        )
    ) {
        self.logo = logo
        self.emptyStateImage = emptyStateImage
    }

    public static let `default` = AIChatBranding()
}

private struct AIChatBrandingKey: EnvironmentKey {
    static let defaultValue = AIChatBranding.default
}

public extension EnvironmentValues {
    var aiChatBranding: AIChatBranding {
        get { self[AIChatBrandingKey.self] }
        set { self[AIChatBrandingKey.self] = newValue }
    }
}

public extension View {
    func aiChatBranding(_ branding: AIChatBranding) -> some View {
        environment(\.aiChatBranding, branding)
    }
}
