// DisplayControlIntents.swift
// AppIntents for Shortcuts integration
//
// Part of DisplayControl
// Licensed under GPL-3.0

import Foundation
import AppIntents
import DisplayControlCore

// MARK: - Mirroring Intents

@available(macOS 14.0, *)
struct ToggleMirroringIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Display Mirroring"
    static var description = IntentDescription("Toggle mirroring on or off for all displays")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = DisplayManager.shared
        try manager.toggleMirroring()
        let state = manager.isMirrored() ? "enabled" : "disabled"
        return .result(dialog: "Display mirroring \(state)")
    }
}

@available(macOS 14.0, *)
struct EnableMirroringIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable Display Mirroring"
    static var description = IntentDescription("Enable mirroring for all displays")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try DisplayManager.shared.enableMirroring()
        return .result(dialog: "Display mirroring enabled")
    }
}

@available(macOS 14.0, *)
struct DisableMirroringIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Display Mirroring"
    static var description = IntentDescription("Disable mirroring for all displays")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try DisplayManager.shared.disableMirroring()
        return .result(dialog: "Display mirroring disabled")
    }
}

// MARK: - Configuration Intents

@available(macOS 14.0, *)
struct ApplyConfigurationIntent: AppIntent {
    static var title: LocalizedStringResource = "Apply Display Configuration"
    static var description = IntentDescription("Apply a named display configuration")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Configuration Name")
    var configurationName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Apply \(\.$configurationName) configuration")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try ConfigurationManager.shared.applyConfiguration(named: configurationName)
        return .result(dialog: "Applied configuration '\(configurationName)'")
    }
}

@available(macOS 14.0, *)
struct ListConfigurationsIntent: AppIntent {
    static var title: LocalizedStringResource = "List Display Configurations"
    static var description = IntentDescription("Get a list of saved display configurations")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let configs = try ConfigurationManager.shared.loadConfigurations()
        let names = configs.map { $0.name }
        return .result(value: names)
    }
}

// MARK: - Resolution Intent

@available(macOS 14.0, *)
struct SetResolutionIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Display Resolution"
    static var description = IntentDescription("Set the resolution for a specific display")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Display Index", default: 0)
    var displayIndex: Int

    @Parameter(title: "Width")
    var width: Int

    @Parameter(title: "Height")
    var height: Int

    @Parameter(title: "Refresh Rate (optional)", default: nil)
    var refreshRate: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Set display \(\.$displayIndex) to \(\.$width)x\(\.$height)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = DisplayManager.shared
        let refresh = refreshRate.map { Double($0) }

        try manager.setMode(
            displayIndex: UInt32(displayIndex),
            width: width,
            height: height,
            refreshRate: refresh
        )

        if let refresh = refreshRate {
            return .result(dialog: "Set display \(displayIndex) to \(width)x\(height)@\(refresh)Hz")
        } else {
            return .result(dialog: "Set display \(displayIndex) to \(width)x\(height)")
        }
    }
}

// MARK: - App Shortcuts Provider

@available(macOS 14.0, *)
struct DisplayControlShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleMirroringIntent(),
            phrases: [
                "Toggle display mirroring in \(.applicationName)",
                "Toggle mirroring with \(.applicationName)"
            ],
            shortTitle: "Toggle Mirroring",
            systemImageName: "rectangle.2.swap"
        )

        AppShortcut(
            intent: EnableMirroringIntent(),
            phrases: [
                "Enable display mirroring in \(.applicationName)",
                "Turn on mirroring with \(.applicationName)"
            ],
            shortTitle: "Enable Mirroring",
            systemImageName: "rectangle.on.rectangle"
        )

        AppShortcut(
            intent: DisableMirroringIntent(),
            phrases: [
                "Disable display mirroring in \(.applicationName)",
                "Turn off mirroring with \(.applicationName)"
            ],
            shortTitle: "Disable Mirroring",
            systemImageName: "rectangle.split.2x1"
        )

        AppShortcut(
            intent: ApplyConfigurationIntent(),
            phrases: [
                "Apply display configuration in \(.applicationName)",
                "Switch to \(\.$configurationName) in \(.applicationName)"
            ],
            shortTitle: "Apply Configuration",
            systemImageName: "gearshape.2"
        )
    }
}
