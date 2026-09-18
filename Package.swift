// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DisplayControl",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        // CLI executable
        .executable(
            name: "displayctrl",
            targets: ["DisplayControl"]
        ),
        // macOS Menu Bar & Preset Manager GUI executable
        .executable(
            name: "DisplayControlApp",
            targets: ["DisplayControlApp"]
        ),
        // UI library (views, preset store, window manager, and previews)
        .library(
            name: "DisplayControlUI",
            targets: ["DisplayControlUI"]
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

        // UI library containing PresetManagerView, PresetStore, WindowManager, and previews
        .target(
            name: "DisplayControlUI",
            dependencies: ["DisplayControlCore"]
        ),

        // CLI executable target
        .executableTarget(
            name: "DisplayControl",
            dependencies: ["DisplayControlCore"]
        ),

        // macOS Menu Bar & Preset Manager GUI target
        .executableTarget(
            name: "DisplayControlApp",
            dependencies: ["DisplayControlCore", "DisplayControlUI"]
        ),

        // Test target
        .testTarget(
            name: "DisplayControlTests",
            dependencies: ["DisplayControlCore"]
        ),
    ]
)
