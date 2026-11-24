// swift-tools-version: 6.0
// Belay.app shell. Built with SwiftPM and wrapped into an .app by scripts/run.sh (ADR 0013).
import PackageDescription

let package = Package(
    name: "Belay",
    platforms: [.macOS(.v14)],
    // No package dependencies: the notch window is our own (ADR 0014), so the app builds with the Command Line Tools alone.
    targets: [
        .executableTarget(
            name: "Belay",
            path: "Sources/Belay",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Network"),
            ]
        ),
    ]
)
