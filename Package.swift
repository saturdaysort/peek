// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Peek",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: parsing, queue, behavior, motion, sprite. No AppKit, fully unit tested.
        .target(name: "PeekCore"),
        // The AppKit app. Swift 5 language mode: its callbacks (Timer, DispatchSource, NSMenu)
        // all run on the main thread, and strict concurrency checking adds ceremony, not safety.
        .executableTarget(
            name: "Peek",
            dependencies: ["PeekCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "PeekCoreTests", dependencies: ["PeekCore"]),
    ]
)
