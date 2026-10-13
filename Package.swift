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
        .library(name: "LemmingsAudio", targets: ["LemmingsAudio"]),
        .library(name: "LemmingsGameArt", targets: ["LemmingsGameArt"]),
        .library(name: "LemmingsMobileCore", targets: ["LemmingsMobileCore"]),
        // Stores and records that the Mac and iPad apps share.
        .library(name: "LemmingsAppCore", targets: ["LemmingsAppCore"]),
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
                          path: "Tools/IOSMenuAudit",
                          swiftSettings: [.unsafeFlags(["-parse-as-library"])]),
        .target(
            name: "NxlvKit",
            path: "Sources/NxlvKit"
        ),
        .target(
            name: "LemmingsAudio",
            dependencies: ["NxlvKit"],
            path: "Sources/LemmingsAudio"
        ),
        .target(
            name: "LemmingsGameArt",
            dependencies: ["NxlvKit", "LemmingsMobileCore"],
            path: "Sources/LemmingsGameArt"
        ),
        .target(
            name: "LemmingsMobileCore",
            dependencies: ["LemmingsAppCore", "NxlvKit"],
            path: "Sources/LemmingsMobileCore"
        ),
        .target(
            name: "LemmingsAppCore",
            dependencies: ["NxlvKit"],
            path: "Sources/LemmingsAppCore"
        ),
        .target(
            name: "LemmingsMobileUI",
            dependencies: ["LemmingsAppCore", "LemmingsAudio", "LemmingsGameArt", "LemmingsMobileCore", "NxlvKit"],
            path: "Sources/LemmingsMobileUI"
        ),
        .executableTarget(
            name: "LemmingsMobileBetaTool",
            dependencies: ["LemmingsMobileCore", "NxlvKit"],
            path: "Tools/IOSBeta",
            exclude: ["content.py", "build.py", "install.py", "artwork.py", "ports.py", "packs.py", "music.py", "game_center.py", "__pycache__"],
            sources: ["validate-content.swift"]
        ),
        .executableTarget(
            name: "LemmingsLocal",
            dependencies: [
                "LemmingsAppCore",
                "LemmingsAudio",
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
            dependencies: ["LemmingsAppCore", "LemmingsAudio", "LemmingsLocal", "NxlvKit"],
            path: "Tests/LemmingsLocalTests"
        ),
        .testTarget(
            name: "LemmingsAppCoreTests",
            dependencies: ["LemmingsAppCore", "NxlvKit"],
            path: "Tests/LemmingsAppCoreTests"
        ),
        .testTarget(
            name: "LemmingsMobileCoreTests",
            dependencies: ["LemmingsAppCore", "LemmingsMobileCore", "NxlvKit"],
            path: "Tests/LemmingsMobileCoreTests"
        ),
        .testTarget(
            name: "LemmingsMobileUITests",
            dependencies: ["LemmingsMobileCore", "LemmingsMobileUI"],
            path: "Tests/LemmingsMobileUITests"
        )
    ]
)
