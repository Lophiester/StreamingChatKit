// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "StreamingChatKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "StreamingChatCore", targets: ["StreamingChatCore"]),
        .library(name: "StreamingChatUI", targets: ["StreamingChatUI"])
    ],
    targets: [
        .target(name: "StreamingChatCore"),
        .target(
            name: "StreamingChatUI",
            dependencies: ["StreamingChatCore"]
        ),
        .testTarget(
            name: "StreamingChatCoreTests",
            dependencies: ["StreamingChatCore"]
        )
    ]
)
