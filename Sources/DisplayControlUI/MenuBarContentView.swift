// MenuBarContentView.swift
// Menu content for DisplayControl MenuBarExtra
//
// Part of DisplayControl
// Licensed under GPL-3.0

import SwiftUI
import DisplayControlCore

public struct MenuBarContentView: View {
    @ObservedObject public var store: PresetStore

    public init(store: PresetStore) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.presets.isEmpty {
                // Empty state: primary CTA to define presets (styled like GUI blank slate)
                Button {
                    WindowManager.shared.showPresetManager(store: store)
                } label: {
                    Label("Define Presets...", systemImage: "display.2")
                }
            } else {
                // Fast switcher list of named presets
                // Uses native Toggle to place checkmark in OS reserved checkmark column (no horizontal text shift)
                ForEach(store.presets, id: \.name) { preset in
                    Toggle(isOn: Binding(
                        get: { store.activePresetName?.lowercased() == preset.name.lowercased() },
                        set: { _ in store.apply(preset: preset) }
                    )) {
                        Text(preset.name)
                    }
                }
            }

            Divider()

            // Always present: Manage presets brings up the GUI (no keyboard shortcuts)
            Button("Manage Presets...") {
                WindowManager.shared.showPresetManager(store: store)
            }

            Divider()

            Button("Quit DisplayControl") {
                NSApp.terminate(nil)
            }
        }
    }
}

#if DEBUG
struct MenuPreviewCard: View {
    @ObservedObject var store: PresetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: store.menuBarIconName)
                Text("DisplayControl")
                    .font(.caption.bold())
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)

            if store.presets.isEmpty {
                // Blank slate preview matching GUI styling
                VStack(spacing: 8) {
                    Image(systemName: "display.2")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No Presets Defined")
                        .font(.caption.bold())
                    Button {
                        // no-op preview
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "display.2")
                            Text("Define Presets...")
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.glassProminent)
                    .glassEffect()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            } else {
                ForEach(store.presets, id: \.name) { preset in
                    let isActive = store.activePresetName?.lowercased() == preset.name.lowercased()
                    HStack(spacing: 8) {
                        // Reserved checkmark space: always fixed width so text never shifts horizontally
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 14, alignment: .center)
                            .opacity(isActive ? 1 : 0)

                        Text(preset.name)
                            .fontWeight(isActive ? .semibold : .regular)

                        Spacer()
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 4)
                }
            }

            Divider()

            HStack {
                Text("Manage Presets...")
                Spacer()
            }
            .padding(.horizontal, 4)

            Divider()

            HStack {
                Text("Quit DisplayControl")
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(10)
        .frame(width: 220)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
        .padding(16)
    }
}

#Preview("Menu Bar - Populated") {
    MenuPreviewCard(store: .preview)
}

#Preview("Menu Bar - Empty") {
    MenuPreviewCard(store: .emptyPreview)
}
#endif
