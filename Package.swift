// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DisplayControl",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // CLI executable
        .executable(
            name: "displayctrl",
            targets: ["DisplayControl"]
        ),
        // Core library (for future widget / shortcuts use)
        .library(
            name: "DisplayControlCore",
            targets: ["DisplayControlCore"]
        ),
    ],
    dependencies: [],
    targets: [
        // Core library containing the display management logic
        .target(
            name: "DisplayControlCore",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
            ]
        ),

        // CLI executable target
        .executableTarget(
            name: "DisplayControl",
            dependencies: ["DisplayControlCore"]
        ),
    ]
)
