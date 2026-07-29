import AIChatSDK
import SwiftUI

/// Main App wrapper that owns the application-specific Voice sheet.
/// The reusable chat interface itself lives in `AIChatSDK.AIChatView`.
struct ChatView: View {
    let viewModel: ChatViewModel

    @State private var isShowingVoiceCall = false

    let theme = AIChatTheme(
        accentColor: .purple,
        titleFont: .largeTitle,
        bodyFont: .custom("Avenir Next", size: 15),
        supportingFont: .custom("Avenir Next", size: 13),
        captionFont: .caption,
        codeFont: .system(.callout, design: .monospaced)
    )

    let branding = AIChatBranding(
        logo: Image("CompanyLogo"),
        emptyStateImage: Image(systemName: "sparkles")
    )

    var body: some View {
        AIChatView(
            viewModel: viewModel,
            theme: theme,
            branding: branding
        )
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        isShowingVoiceCall = true
                    } label: {
                        Label("Sesli Görüşme", systemImage: "phone.fill")
                    }
                }
            }
            .sheet(isPresented: $isShowingVoiceCall) {
                VoiceCallView(
                    viewModel: VoiceCallViewModel(chatViewModel: viewModel)
                )
            }
    }
}
