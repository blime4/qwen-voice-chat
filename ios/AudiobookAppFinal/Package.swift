// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudiobookApp",
    platforms: [.iOS(.v17)],
    products: [
        .executable(name: "AudiobookApp", targets: ["AudiobookApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AudiobookApp",
            dependencies: [],
            path: "."
        )
    ]
)
