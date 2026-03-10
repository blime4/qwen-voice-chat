// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudiobookApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AudiobookApp", targets: ["AudiobookApp"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AudiobookApp",
            dependencies: ["ChatLLMBridge"]
        ),
        .target(
            name: "ChatLLMBridge",
            dependencies: [],
            path: "Sources/ChatLLMBridge",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                .headerSearchPath("include"),
            ]
        ),
        .testTarget(
            name: "AudiobookAppTests",
            dependencies: ["AudiobookApp"]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
