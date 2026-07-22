// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AIChatSDK",
    platforms: [
        .macOS("26.5")
    ],
    products: [
        .library(name: "AIChatSDK", targets: ["AIChatSDK"])
    ],
    targets: [
        .target(
            name: "AIChatSDK",
            resources: [
                .copy("Resources/AIChat.xcdatamodeld"),
                .copy("Resources/Compiled/AIChatPrecompiled.momd")
            ]
        ),
        .testTarget(name: "AIChatSDKTests", dependencies: ["AIChatSDK"])
    ]
)
