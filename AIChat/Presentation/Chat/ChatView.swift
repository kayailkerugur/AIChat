import AIChatSDK
import SwiftUI

/// Main App wrapper that owns the application-specific Voice sheet.
/// The reusable chat interface itself lives in `AIChatSDK.AIChatView`.
struct ChatView: View {
    let viewModel: ChatViewModel

    @State private var isShowingVoiceCall = false

    var body: some View {
        AIChatView(viewModel: viewModel)
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
