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
        .library(name: "LemmingsGameArt", targets: ["LemmingsGameArt"]),
        .library(name: "LemmingsMobileCore", targets: ["LemmingsMobileCore"]),
        .library(name: "LemmingsMobileUI", targets: ["LemmingsMobileUI"]),
        .executable(name: "LemmingsLocal", targets: ["LemmingsLocal"]),
        .executable(name: "LemmingsDataTool", targets: ["LemmingsDataTool"]),
        .executable(name: "LemmingsMobileBetaTool", targets: ["LemmingsMobileBetaTool"]),
        .executable(name: "LemmingsMobileMenuAudit", targets: ["LemmingsMobileMenuAudit"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.7.3")
    ],
    targets: [
        .executableTarget(name: "LemmingsMobileMenuAudit", dependencies: ["LemmingsGameArt", "LemmingsMobileCore"],
                          path: "Tools/IOSMenuAudit"),
        .target(
            name: "NxlvKit",
            path: "Sources/NxlvKit"
        ),
        .target(
            name: "LemmingsGameArt",
            dependencies: ["NxlvKit"],
            path: "Sources/LemmingsGameArt"
        ),
        .target(
            name: "LemmingsMobileCore",
            dependencies: ["NxlvKit"],
            path: "Sources/LemmingsMobileCore"
        ),
        .target(
            name: "LemmingsMobileUI",
            dependencies: ["LemmingsGameArt", "LemmingsMobileCore", "NxlvKit"],
            path: "Sources/LemmingsMobileUI"
        ),
        .executableTarget(
            name: "LemmingsMobileBetaTool",
            dependencies: ["LemmingsMobileCore", "NxlvKit"],
            path: "Tools/IOSBeta",
            exclude: ["content.py", "build.py", "install.py", "artwork.py", "__pycache__"],
            sources: ["validate-content.swift"]
        ),
        .executableTarget(
            name: "LemmingsLocal",
            dependencies: [
                "LemmingsGameArt",
                "NxlvKit",
                .product(name: "Sparkle", package: "Sparkle", condition: .when(platforms: [.macOS]))
            ],
            path: "Sources/LemmingsLocal"
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
