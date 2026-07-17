import AIChatSDK
import SwiftUI

@MainActor
func makeSDKRootView() -> some View {
    AIChatSDKView(
        configuration: AIChatSDKConfiguration(
            branding: .init(
                applicationName: "Empty Host",
                accentColor: .blue,
                logoSystemName: "bubble.left"
            ),
            licenseKey: "integration-test"
        )
    )
}
