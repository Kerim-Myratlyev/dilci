// swift-tools-version:5.9
// Lets the platform-independent core (languages, slang, culture notes) be
// unit-tested with `swift test` on macOS, without a simulator.
// The app itself is still built from Dilci.xcodeproj.
import PackageDescription

let package = Package(
    name: "DilciCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    targets: [
        .target(
            name: "DilciCore",
            path: "Shared",
            sources: ["Models.swift", "Slang.swift", "CultureNotes.swift"]
        ),
        .testTarget(
            name: "DilciCoreTests",
            dependencies: ["DilciCore"],
            path: "Tests/DilciCoreTests"
        ),
    ]
)
