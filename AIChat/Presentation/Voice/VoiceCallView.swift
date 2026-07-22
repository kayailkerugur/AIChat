import AIChatSDK
import AppKit
import SwiftUI

/// Main App wrapper that applies application-window behavior to the
/// reusable SDK voice interface.
struct VoiceCallView: View {
    let viewModel: VoiceCallViewModel

    var body: some View {
        AIChatVoiceView(viewModel: viewModel)
            .background(WindowResizeEnabler())
    }
}

private struct WindowResizeEnabler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.styleMask.insert(.resizable)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
