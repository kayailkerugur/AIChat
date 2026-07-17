# AIChatSDK Integration

## Requirements

- macOS 15 or later
- Xcode 16 or later
- Microphone, speech recognition, outgoing network, and user-selected-file permissions in the host application

The host application owns signing, entitlements, privacy usage descriptions, OAuth callback handling, and its `@main` lifecycle.

When adding `AIChatSDK.xcframework` directly, select the host target and set the framework to **Embed & Sign** under **General → Frameworks, Libraries, and Embedded Content**. In **Build Phases**, it must appear under both **Link Binary With Libraries** and **Embed Frameworks**, with **Code Sign On Copy** enabled. The framework is built with an `@rpath` install name so it is loaded from the host application's `Contents/Frameworks` directory.

## Binary Swift Package

1. Run `scripts/build-xcframework.sh`.
2. Upload `Build/Distribution/AIChatSDK.xcframework.zip` to a stable HTTPS release URL.
3. Copy the checksum printed by the script into `BinaryPackage/Package.swift`.
4. Replace the placeholder download URL.
5. Add the package repository to the host project and link the `AIChatSDK` product.

## SwiftUI usage

```swift
import AIChatSDK
import SwiftUI

@main
struct HostApp: App {
    var body: some Scene {
        WindowGroup {
            AIChatSDKView(
                configuration: AIChatSDKConfiguration(
                    branding: .init(
                        applicationName: "Support Assistant",
                        accentColor: .purple,
                        logoSystemName: "sparkles",
                        loginSubtitle: "Sign in to continue"
                    ),
                    licenseKey: "YOUR-LICENSE-KEY",
                    googleOAuth: .init(
                        clientID: "YOUR_CLIENT_ID.apps.googleusercontent.com"
                    )
                )
            )
        }
    }
}
```

`AIChatSDKDelegate` reports successful startup and license failures. Supply an implementation of `AIChatSDKLicenseValidating` to connect license checks to the production licensing service. The built-in allow-all validator exists for local development and must not be used as the production policy.

## Host permissions

Add `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` to the host Info.plist. Enable App Sandbox permissions for outgoing network connections, microphone input, and read-only user-selected files.

## Google OAuth configuration

Create a separate Google OAuth client for every host bundle identifier. In Google Cloud Console create an **iOS OAuth client**, enter the host application's exact bundle identifier, and pass the resulting client ID through `AIChatSDKConfiguration.GoogleOAuth`.

Register the reversed client ID in the host target under **Info → URL Types → URL Schemes**. For a client ID such as:

```text
123-example.apps.googleusercontent.com
```

the URL scheme is:

```text
com.googleusercontent.apps.123-example
```

The value is also available as `googleOAuth.callbackURLScheme`. The SDK sends `com.googleusercontent.apps.123-example:/oauth2redirect` as its redirect URI. The URL type must be registered by the host application, not by the framework bundle.

## Clean-project verification

Create an empty macOS SwiftUI app, add the binary package, paste the usage example, apply the host permissions, and confirm that:

- the package imports without exposing internal implementation types;
- the login screen uses the configured name, color, logo, and subtitle;
- Core Data resources load from `AIChatSDK.framework`;
- OAuth, provider configuration, chat streaming, attachments, and voice features work;
- removing or rejecting the license prevents SDK startup and invokes the delegate.
