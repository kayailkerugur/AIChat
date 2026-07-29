// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AIChatSDK",
    platforms: [
        .macOS("26.5")
    ],
    products: [
        .library(
            name: "AIChatSDK",
            type: .dynamic,
            targets: ["AIChatSDK"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/sharplet/swift-cgit2",
            exact: "1.1.1"
        )
    ],
    targets: [
        .target(
            name: "AIChatSDK",
            dependencies: [
                .product(name: "Cgit2", package: "swift-cgit2")
            ],
            resources: [
                .copy("Resources/AIChat.xcdatamodeld"),
                .copy("Resources/Compiled/AIChatPrecompiled.momd")
            ]
        ),
        .testTarget(name: "AIChatSDKTests", dependencies: ["AIChatSDK"])
    ]
)
