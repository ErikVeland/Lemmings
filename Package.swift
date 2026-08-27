// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "LemmingsNativePort",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        // Shared format, rendering, and simulation code.
        .library(name: "NxlvKit", targets: ["NxlvKit"]),
        .executable(name: "LemmingsLocal", targets: ["LemmingsLocal"]),
        .executable(name: "LemmingsDataTool", targets: ["LemmingsDataTool"])
    ],
    targets: [
        .target(
            name: "NxlvKit",
            path: "Sources/NxlvKit"
        ),
        .executableTarget(
            name: "LemmingsLocal",
            dependencies: ["NxlvKit"],
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
        )
    ]
)
