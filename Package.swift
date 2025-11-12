// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DisplayControl",
    platforms: [
        .macOS(.v14) // Required for Control Center widgets and modern AppIntents
    ],
    products: [
        // CLI executable
        .executable(
            name: "displayctl",
            targets: ["DisplayControl"]
        ),
        // Library for widget and shortcuts
        .library(
            name: "DisplayControlCore",
            targets: ["DisplayControlCore"]
        ),
    ],
    dependencies: [
        // No external dependencies needed - using native CoreGraphics
    ],
    targets: [
        // Core library containing the display management logic
        .target(
            name: "DisplayControlCore",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Foundation"),
            ]
        ),

        // CLI executable target
        .executableTarget(
            name: "DisplayControl",
            dependencies: ["DisplayControlCore"]
        ),

        // Widget target for Control Center
        .target(
            name: "DisplayControlWidget",
            dependencies: ["DisplayControlCore"],
            linkerSettings: [
                .linkedFramework("WidgetKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),

        // AppIntents for Shortcuts support
        .target(
            name: "DisplayControlIntents",
            dependencies: ["DisplayControlCore"],
            linkerSettings: [
                .linkedFramework("AppIntents"),
            ]
        ),

        // Tests
        .testTarget(
            name: "DisplayControlTests",
            dependencies: ["DisplayControlCore"]
        ),
    ]
)
