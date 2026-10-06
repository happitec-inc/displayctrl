// DisplayControlWidget.swift
// Control Center widget for DisplayControl
//
// Part of DisplayControl
// Licensed under GPL-3.0

import Foundation
import WidgetKit
import SwiftUI
import AppIntents
import DisplayControlCore

// MARK: - Widget Toggle Intent

@available(macOS 26.0, *)
struct ToggleMirroringControlIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Mirroring"

      @Parameter(title: "Mirroring")
    var value: Bool

    init() {
        self.value = false
      }

    init(value: Bool) {
        self.value = value
      }

    func perform() async throws -> some IntentResult {
        try DisplayManager.shared.toggleMirroring()
        return .result()
      }
}

// MARK: - Configuration Entity

/// An `AppEntity` view of a saved `DisplayConfiguration`. The attached
/// `ConfigurationQuery` reads `ConfigurationManager.shared` live, so presets
/// saved via the CLI or the GUI app appear in the control's picker without
/// rebuilding the widget.
@available(macOS 26.0, *)
struct ConfigurationEntity: AppEntity {
    let id: String
    let name: String
    let displayCount: Int
    let mirroringEnabled: Bool

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display Configuration")
    static let defaultQuery = ConfigurationQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(displayCount) display(s), mirroring \(mirroringEnabled ? "on" : "off")"
          )
      }
}

@available(macOS 26.0, *)
struct ConfigurationQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ConfigurationEntity] {
        let configurations = try ConfigurationManager.shared.loadConfigurations()
        return configurations
              .filter { identifiers.contains($0.name) }
              .map(Self.entity(for:))
      }

    func suggestedEntities() async throws -> [ConfigurationEntity] {
        try ConfigurationManager.shared.loadConfigurations().map(Self.entity(for:))
      }

    static func entity(for config: DisplayConfiguration) -> ConfigurationEntity {
        ConfigurationEntity(
            id: config.name,
            name: config.name,
            displayCount: config.displays.count,
            mirroringEnabled: config.mirroring == .enabled
          )
      }
}

// MARK: - Configuration Picker Intent

/// Doubles as the control's configuration intent and its action: Control
/// Center prompts the user to pick a configuration (rendered from
/// `ConfigurationQuery`) when the control is added, and applying the control
/// runs the intent with the chosen entity.
@available(macOS 26.0, *)
struct SelectConfigurationIntent: AppIntent, ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Apply Configuration"
    static let openAppWhenRun: Bool = false

      @Parameter(title: "Configuration")
    var value: ConfigurationEntity?

    func perform() async throws -> some IntentResult {
        guard let value else {
            throw ConfigurationError.notFound("selected configuration")
           }
        try ConfigurationManager.shared.applyConfiguration(named: value.id)
        return .result()
      }
}

// MARK: - Control Widget

@available(macOS 26.0, *)
struct DisplayMirroringControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.displaycontrol.mirroring"
          ) {
            ControlWidgetToggle(
                isOn: DisplayManager.shared.isMirrored(),
                action: ToggleMirroringControlIntent()
              ) {
                Label("Display Mirroring", systemImage: "rectangle.on.rectangle")
              }
          }
          .displayName("Display Mirroring")
          .description("Toggle display mirroring on or off")
      }
}

// MARK: - Configuration Selector Control

@available(macOS 26.0, *)
struct ConfigurationSelectorControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: "com.displaycontrol.configuration",
            intent: SelectConfigurationIntent.self
          ) { intent in
            ControlWidgetButton(action: intent) {
                Label("Configurations", systemImage: "gearshape.2")
              }
          }
          .displayName("Display Configuration")
          .description("Apply a saved display configuration")
          .promptsForUserConfiguration()
      }
}

// MARK: - Widget Bundle

@available(macOS 26.0, *)
@main
struct DisplayControlWidgetBundle: WidgetBundle {
    var body: some Widget {
        DisplayMirroringControl()
        ConfigurationSelectorControl()
      }
}
