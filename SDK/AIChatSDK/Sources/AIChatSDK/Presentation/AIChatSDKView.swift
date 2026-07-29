import SwiftUI

/// Mode-aware SDK entry view.
///
/// The integrating application fixes the mode through `AIChatConfiguration`.
/// No mode picker is shown to the end user.
public struct AIChatSDKView: View {
    @State private var chatViewModel: ChatViewModel
    @State private var codeViewModel: CodeModeViewModel?

    private let mode: AIChatMode
    private let theme: AIChatTheme?
    private let branding: AIChatBranding?
    private let repositorySelectionAction: (() -> Void)?

    @MainActor
    public init(
        client: AIChatClient,
        conversation: Conversation,
        theme: AIChatTheme? = nil,
        branding: AIChatBranding? = nil,
        onSelectRepository: (() -> Void)? = nil,
        onConversationMutated: @escaping @MainActor () -> Void = {}
    ) throws {
        mode = client.configuration.mode
        self.theme = theme
        self.branding = branding
        repositorySelectionAction = onSelectRepository
        let codeViewModel = mode == .code
            ? try client.makeCodeModeViewModel(for: conversation)
            : nil
        _chatViewModel = State(
            initialValue: try client.makeChatViewModel(
                for: conversation,
                contextProvider: codeViewModel,
                onConversationMutated: onConversationMutated
            )
        )
        _codeViewModel = State(initialValue: codeViewModel)
    }

    public var body: some View {
        Group {
            switch mode {
            case .standard:
                AIChatView(
                    viewModel: chatViewModel,
                    theme: theme,
                    branding: branding
                )
            case .code:
                if let codeViewModel {
                    AIChatCodeView(
                        codeViewModel: codeViewModel,
                        chatViewModel: chatViewModel,
                        theme: theme,
                        branding: branding,
                        onSelectRepository: repositorySelectionAction
                    )
                }
            }
        }
    }
}
