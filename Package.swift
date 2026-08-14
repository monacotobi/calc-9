// swift-tools-version: 5.9
import PackageDescription

// This package exists ONLY to test the expression engine.
//
// The engine is pure Swift with no AppKit, so it can be built and tested without a window
// server — which is what makes `swift test` and fast CI possible here. The Xcode app target
// compiles the same files in Sources/Engine directly into the app; nothing is duplicated,
// and the tests exercise exactly the code that ships.
let package = Package(
    name: "Calc9Engine",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Calc9Engine", targets: ["Calc9Engine"])
    ],
    targets: [
        .target(name: "Calc9Engine", path: "Sources/Engine"),
        .testTarget(name: "Calc9EngineTests", dependencies: ["Calc9Engine"], path: "Tests")
    ]
)
