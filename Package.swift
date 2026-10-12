// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Deskling",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "DesklingCore"),
        .executableTarget(name: "deskling-hook", dependencies: ["DesklingCore"], path: "Sources/deskling-hook"),
        .testTarget(name: "DesklingCoreTests", dependencies: ["DesklingCore"]),
    ]
)
