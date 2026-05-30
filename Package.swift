// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Chronos",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Chronos", targets: ["Chronos"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Chronos",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .unsafeFlags(["-warn-concurrency"], .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "ChronosTests",
            dependencies: ["Chronos"],
            path: "Tests/ChronosTests"
        )
    ]
)
