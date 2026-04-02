// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlogEngineCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BlogEngineCore",
            targets: ["BlogEngineCore"]
        ),
    ],
    targets: [
        .target(
            name: "BlogEngineCore",
            path: "."
        ),
    ]
)
