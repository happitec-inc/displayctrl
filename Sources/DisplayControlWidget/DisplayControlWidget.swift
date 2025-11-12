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

@available(macOS 14.0, *)
struct ToggleMirroringControlIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Toggle Mirroring"

    func perform() async throws -> some IntentResult {
        try DisplayManager.shared.toggleMirroring()
        return .result()
    }
}

// MARK: - Configuration Selector Intent

@available(macOS 14.0, *)
struct SelectConfigurationIntent: SetValueIntent, ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Apply Configuration"

    @Parameter(title: "Configuration")
    var value: String

    func perform() async throws -> some IntentResult {
        try ConfigurationManager.shared.applyConfiguration(named: value)
        return .result()
    }
}

// MARK: - Control Widget Configuration

@available(macOS 14.0, *)
struct MirroringToggleControlConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Display Mirroring"

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Control Widget

@available(macOS 14.0, *)
struct DisplayMirroringControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.displaycontrol.mirroring"
        ) {
            ControlWidgetToggle(
                isOn: DisplayManager.shared.isMirrored(),
                action: ToggleMirroringControlIntent()
            ) { isOn in
                Label(isOn ? "Mirroring On" : "Mirroring Off", systemImage: "rectangle.on.rectangle")
            }
        }
        .displayName("Display Mirroring")
        .description("Toggle display mirroring on or off")
    }
}

// MARK: - Configuration Selector Control

@available(macOS 14.0, *)
struct ConfigurationSelectorControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.displaycontrol.configuration"
        ) {
            ControlWidgetButton(action: ShowConfigurationMenuIntent()) {
                Label("Configurations", systemImage: "gearshape.2")
            }
        }
        .displayName("Display Configuration")
        .description("Apply saved display configurations")
    }
}

@available(macOS 14.0, *)
struct ShowConfigurationMenuIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Configurations"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let configs = try ConfigurationManager.shared.loadConfigurations()

        return .result(
            snippet: ConfigurationListView(configurations: configs)
        )
    }
}

@available(macOS 14.0, *)
struct ConfigurationListView: View {
    let configurations: [DisplayConfiguration]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Configurations")
                .font(.headline)
                .padding(.bottom, 4)

            if configurations.isEmpty {
                Text("No saved configurations")
                    .foregroundColor(.secondary)
            } else {
                ForEach(configurations, id: \.name) { config in
                    Button(action: {
                        Task {
                            try? ConfigurationManager.shared.applyConfiguration(config)
                        }
                    }) {
                        HStack {
                            Image(systemName: config.mirroring == .enabled ? "rectangle.on.rectangle" : "rectangle.split.2x1")
                            VStack(alignment: .leading) {
                                Text(config.name)
                                    .font(.body)
                                Text("\(config.displays.count) display(s)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .frame(maxWidth: 300)
    }
}

// MARK: - Widget Bundle

@available(macOS 14.0, *)
@main
struct DisplayControlWidgetBundle: WidgetBundle {
    var body: some Widget {
        DisplayMirroringControl()
        ConfigurationSelectorControl()
    }
}
