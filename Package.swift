// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "LemmingsNativePort",
    platforms: [
        .macOS("12.3"),
        .iOS(.v16)
    ],
    products: [
        // Shared format, rendering, and simulation code.
        .library(name: "NxlvKit", targets: ["NxlvKit"]),
        .library(name: "LemmingsMobileCore", targets: ["LemmingsMobileCore"]),
        .library(name: "LemmingsMobileUI", targets: ["LemmingsMobileUI"]),
        .executable(name: "LemmingsLocal", targets: ["LemmingsLocal"]),
        .executable(name: "LemmingsDataTool", targets: ["LemmingsDataTool"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.7.3")
    ],
    targets: [
        .target(
            name: "NxlvKit",
            path: "Sources/NxlvKit"
        ),
        .target(
            name: "LemmingsMobileCore",
            dependencies: ["NxlvKit"],
            path: "Sources/LemmingsMobileCore"
        ),
        .target(
            name: "LemmingsMobileUI",
            dependencies: ["LemmingsMobileCore", "NxlvKit"],
            path: "Sources/LemmingsMobileUI"
        ),
        .executableTarget(
            name: "LemmingsLocal",
            dependencies: [
                "NxlvKit",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/LemmingsLocal",
            swiftSettings: [
                .enableExperimentalFeature("IsolatedDeinit")
            ]
        ),
        .executableTarget(
            name: "LemmingsDataTool",
            dependencies: ["NxlvKit"],
            path: "Sources/LemmingsDataTool"
        ),
        .testTarget(
            name: "NxlvKitTests",
            dependencies: ["NxlvKit"],
            path: "Tests/NxlvKitTests"
        ),
        .testTarget(
            name: "LemmingsLocalTests",
            dependencies: ["LemmingsLocal", "NxlvKit"],
            path: "Tests/LemmingsLocalTests"
        ),
        .testTarget(
            name: "LemmingsMobileCoreTests",
            dependencies: ["LemmingsMobileCore", "NxlvKit"],
            path: "Tests/LemmingsMobileCoreTests"
        )
    ]
)
