// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AIChatSDKBinary",
    platforms: [
        .macOS("26.5")
    ],
    products: [
        .library(name: "AIChatSDK", targets: ["AIChatSDK"])
    ],
    targets: [
        .binaryTarget(
            name: "AIChatSDK",
            url: "https://example.com/releases/AIChatSDK.xcframework.zip",
            checksum: "<swift-package-checksum>"
        )
    ]
)
