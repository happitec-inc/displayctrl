// swift-tools-version: 6.3
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
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
    ],
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

        // Test target
        .testTarget(
            name: "DisplayControlTests",
            dependencies: ["DisplayControlCore"]
        ),
    ]
)
