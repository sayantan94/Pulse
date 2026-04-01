// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "PulseCore",
            path: "Sources/PulseCore"
        ),
        .executableTarget(
            name: "Pulse",
            dependencies: ["PulseCore"],
            path: "Sources/Pulse"
        ),
        .testTarget(
            name: "PulseTests",
            dependencies: ["PulseCore"],
            path: "Tests"
        )
    ]
)
