// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Peek",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: parsing, queue, behavior, motion, sprite. No AppKit, fully unit tested.
        .target(name: "PeekCore"),
        .testTarget(name: "PeekCoreTests", dependencies: ["PeekCore"]),
    ]
)
