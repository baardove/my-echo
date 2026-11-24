// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Echo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "EchoCore", targets: ["EchoCore"]),
        .executable(name: "Echo", targets: ["EchoApp"])
    ],
    targets: [
        .target(
            name: "EchoCore",
            path: "Sources/EchoCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "EchoApp",
            dependencies: ["EchoCore"],
            path: "Sources/EchoApp"
        ),
        .testTarget(
            name: "EchoCoreTests",
            dependencies: ["EchoCore"],
            path: "Tests/EchoCoreTests"
        )
    ]
)
