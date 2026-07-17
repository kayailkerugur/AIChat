// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIChatSDK",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AIChatSDK", targets: ["AIChatSDK"])
    ],
    targets: [
        .binaryTarget(
            name: "AIChatSDK",
            url: "https://example.com/releases/AIChatSDK.xcframework.zip",
            checksum: "404c3d752ee6d5021d64e936180c349397c2ed4c35f516c9e527d33499cdd2ea"
        )
    ]
)
