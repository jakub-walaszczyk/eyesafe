// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EyeSafe",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "EyeSafe",
            path: "Sources/EyeSafe",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
