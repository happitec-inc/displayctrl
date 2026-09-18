// MenuBarPopupView.swift
// Liquid Glass popup card for the native macOS Menu Bar Extra
//
// Part of DisplayControl
// Licensed under GPL-3.0

import SwiftUI
import DisplayControlCore

public struct MenuBarPopupView: View {
    @ObservedObject public var store: PresetStore

    @Environment(\.dismiss) private var dismiss

    public init(store: PresetStore) {
        self.store = store
    }

    private func dismissPopup() {
        dismiss()
        for window in NSApp.windows where window.isVisible {
            window.orderOut(nil)
        }
    }

    private func dismissAndOpenManager() {
        dismissPopup()
        AppHandoff.openPresetManager()
    }

    private func selectPreset(_ preset: DisplayConfiguration) {
        dismissPopup()
        store.apply(preset: preset)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: store.menuBarIconName)
                    .font(.system(size: 13, weight: .semibold))
                Text("DisplayControl")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.top, 2)

            if store.presets.isEmpty {
                // Empty state matching the Preset Manager empty slate
                VStack(spacing: 8) {
                    Image(systemName: "display.2")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No Presets Defined")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Define a preset to quickly switch setups from the menu bar.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    Button {
                        dismissAndOpenManager()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "display.2")
                            Text("Define Presets...")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.glassProminent)
                    .glassEffect()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            } else {
                // Fast preset switcher
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(store.presets, id: \.name) { preset in
                        let isActive = store.activePresetName?.lowercased() == preset.name.lowercased()
                        Button {
                            selectPreset(preset)
                        } label: {
                            HStack(spacing: 8) {
                                // Reserved checkmark space: fixed width so text never shifts horizontally
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(width: 14, alignment: .center)
                                    .opacity(isActive ? 1 : 0)

                                Text(preset.name)
                                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))

                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                        }
                        .buttonStyle(.plain)
                        .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                        .cornerRadius(5)
                    }
                }
            }

            Divider()

            // Manage Presets CTA
            Button {
                dismissAndOpenManager()
            } label: {
                HStack {
                    Text("Manage Presets...")
                        .font(.system(size: 12))
                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
            }
            .buttonStyle(.plain)

            Divider()

            // Quit
            Button {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Text("Quit DisplayControl Menu")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 230)
        .onAppear {
            store.load()
        }
    }
}
