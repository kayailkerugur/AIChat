import AIChatSDK
import SwiftUI

@main
struct AIChatDemoApp: App {
    var body: some Scene {
        WindowGroup {
            AIChatSDKView(
                configuration: AIChatSDKConfiguration(
                    branding: .init(
                        applicationName: "AI Chat Demo",
                        accentColor: .indigo,
                        logoSystemName: "bubble.left.and.bubble.right.fill"
                    ),
                    googleOAuth: .init(
                        clientID: "322950785121-eg4r8f9k787iecdlnt3ike6as4el1flm.apps.googleusercontent.com"
                    )
                )
            )
            .frame(minWidth: 720, minHeight: 480)
        }
        .defaultSize(width: 1000, height: 680)
        .windowResizability(.contentMinSize)
    }
}
