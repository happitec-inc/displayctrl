// PresetStore.swift
// Observable state store for DisplayControl presets and live display management
//
// Part of DisplayControl
// Licensed under GPL-3.0

import Foundation
import CoreGraphics
import DisplayControlCore

@MainActor
public final class PresetStore: ObservableObject {
    @Published public var presets: [DisplayConfiguration] = []
    @Published public var onlineDisplays: [DisplayInfo] = []
    @Published public var isMirrored: Bool = false
    @Published public var activePresetName: String? = nil
    @Published public var errorMessage: String? = nil
    @Published public var successMessage: String? = nil

    private var reconfigurationCallbackRegistered = false

    public init(
        presets: [DisplayConfiguration]? = nil,
        onlineDisplays: [DisplayInfo]? = nil,
        isMirrored: Bool = false,
        activePresetName: String? = nil,
        isPreview: Bool = false
    ) {
        if isPreview {
            self.presets = presets ?? []
            self.onlineDisplays = onlineDisplays ?? []
            self.isMirrored = isMirrored
            self.activePresetName = activePresetName
        } else {
            load()
            registerDisplayReconfigurationCallback()
        }
    }

    deinit {
        // CGDisplayRemoveReconfigurationCallback takes nonisolated C function pointer
    }

    /// Reloads all presets from disk and updates current display status.
    public func load() {
        do {
            self.presets = try ConfigurationManager.shared.loadConfigurations()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to load presets: \(error.localizedDescription)"
            self.presets = []
        }

        refreshDisplays()
        updateActivePreset()
    }

    /// Queries online displays and mirroring state from CoreGraphics.
    public func refreshDisplays() {
        do {
            self.onlineDisplays = try DisplayManager.shared.getDisplays()
            self.isMirrored = DisplayManager.shared.isMirrored()
        } catch {
            self.errorMessage = "Failed to query displays: \(error.localizedDescription)"
            self.onlineDisplays = []
        }
    }

    /// Determines which preset (if any) currently matches the live display topology.
    public func updateActivePreset() {
        guard !onlineDisplays.isEmpty else {
            activePresetName = nil
            return
        }

        for preset in presets {
            if matchesLiveSetup(preset) {
                activePresetName = preset.name
                return
            }
        }

        activePresetName = nil
    }

    /// Evaluates if a preset matches the current live display state.
    public func matchesLiveSetup(_ preset: DisplayConfiguration) -> Bool {
        // Check mirroring policy if specified
        switch preset.mirroring {
        case .enabled:
            if !isMirrored { return false }
        case .disabled:
            if isMirrored { return false }
        case .unchanged:
            break
        }

        // Check each display configured in the preset
        for displayConfig in preset.displays {
            let matchedDisplay: DisplayInfo?
            if let serial = displayConfig.serialNumber,
               let bySerial = onlineDisplays.first(where: { $0.serialNumber == serial }) {
                matchedDisplay = bySerial
            } else {
                matchedDisplay = onlineDisplays.first(where: { $0.index == displayConfig.index })
            }

            guard let liveDisplay = matchedDisplay, let currentMode = liveDisplay.currentMode else {
                return false
            }

            if let targetWidth = displayConfig.width, targetWidth != currentMode.width {
                return false
            }
            if let targetHeight = displayConfig.height, targetHeight != currentMode.height {
                return false
            }
            if let targetRefresh = displayConfig.refreshRate {
                if abs(targetRefresh - currentMode.refreshRate) >= 0.5 {
                    return false
                }
            }
        }

        return true
    }

    /// Applies a preset to online displays.
    public func apply(preset: DisplayConfiguration) {
        do {
            try ConfigurationManager.shared.applyConfiguration(preset)
            self.errorMessage = nil
            self.successMessage = "Applied preset '\(preset.name)'"
            // Re-query after display mode changes settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.refreshDisplays()
                self?.updateActivePreset()
            }
        } catch {
            self.errorMessage = "Failed to apply '\(preset.name)': \(error.localizedDescription)"
            self.successMessage = nil
        }
    }

    /// Captures the current live display configuration as a named preset.
    public func captureCurrent(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.errorMessage = "Preset name cannot be empty"
            return false
        }

        do {
            let captured = try ConfigurationManager.shared.captureCurrentConfiguration(name: trimmed)
            try ConfigurationManager.shared.saveConfiguration(captured)
            self.errorMessage = nil
            self.successMessage = "Saved preset '\(trimmed)'"
            load()
            return true
        } catch {
            self.errorMessage = "Failed to capture setup: \(error.localizedDescription)"
            return false
        }
    }

    /// Saves or updates a preset, handling rename if oldName is specified.
    public func save(preset: DisplayConfiguration, renamingFrom oldName: String? = nil) -> Bool {
        let trimmed = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.errorMessage = "Preset name cannot be empty"
            return false
        }

        do {
            if let oldName = oldName, oldName.lowercased() != trimmed.lowercased() {
                try ConfigurationManager.shared.deleteConfiguration(named: oldName)
            }
            try ConfigurationManager.shared.saveConfiguration(preset)
            self.errorMessage = nil
            self.successMessage = "Saved preset '\(preset.name)'"
            load()
            return true
        } catch {
            self.errorMessage = "Failed to save preset: \(error.localizedDescription)"
            return false
        }
    }

    /// Deletes a preset by name.
    public func delete(preset: DisplayConfiguration) {
        do {
            try ConfigurationManager.shared.deleteConfiguration(named: preset.name)
            self.errorMessage = nil
            self.successMessage = "Deleted preset '\(preset.name)'"
            load()
        } catch {
            self.errorMessage = "Failed to delete preset: \(error.localizedDescription)"
        }
    }

    /// Dynamic SF Symbol for menu bar based on mirroring and status.
    public var menuBarIconName: String {
        if isMirrored {
            return "display.2"
        } else {
            return "display"
        }
    }

    private func registerDisplayReconfigurationCallback() {
        guard !reconfigurationCallbackRegistered else { return }
        reconfigurationCallbackRegistered = true

        CGDisplayRegisterReconfigurationCallback({ displayID, flags, userInfo in
            if flags.contains(.desktopShapeChangedFlag) || flags.contains(.setModeFlag) || flags.contains(.addFlag) || flags.contains(.removeFlag) {
                DispatchQueue.main.async {
                    guard let userInfo = userInfo else { return }
                    let store = Unmanaged<PresetStore>.fromOpaque(userInfo).takeUnretainedValue()
                    store.load()
                }
            }
        }, Unmanaged.passUnretained(self).toOpaque())
    }
}

#if DEBUG
extension PresetStore {
    public static var preview: PresetStore {
        let sampleModes = [
            DisplayMode(width: 3024, height: 1964, refreshRate: 120, isCurrent: true),
            DisplayMode(width: 2560, height: 1440, refreshRate: 60),
            DisplayMode(width: 1920, height: 1080, refreshRate: 60)
        ]
        let sampleDisplays = [
            DisplayInfo(
                id: 1,
                index: 0,
                isMain: true,
                isMirrored: false,
                serialNumber: 12345,
                currentMode: sampleModes[0],
                availableModes: sampleModes
            ),
            DisplayInfo(
                id: 2,
                index: 1,
                isMain: false,
                isMirrored: false,
                serialNumber: 67890,
                currentMode: sampleModes[1],
                availableModes: sampleModes
            )
        ]
        let samplePresets = [
            DisplayConfiguration(
                name: "Studio Extended",
                mirroring: .disabled,
                displays: [
                    DisplayConfiguration.DisplayConfig(index: 0, serialNumber: 12345, width: 3024, height: 1964, refreshRate: 120),
                    DisplayConfiguration.DisplayConfig(index: 1, serialNumber: 67890, width: 2560, height: 1440, refreshRate: 60)
                ]
            ),
            DisplayConfiguration(
                name: "Presentation Mirror",
                mirroring: .enabled,
                displays: [
                    DisplayConfiguration.DisplayConfig(index: 0, serialNumber: 12345, width: 1920, height: 1080, refreshRate: 60)
                ]
            ),
            DisplayConfiguration(
                name: "iPad Sidecar",
                mirroring: .disabled,
                displays: [
                    DisplayConfiguration.DisplayConfig(index: 0, serialNumber: 12345, width: 2048, height: 1536, refreshRate: 60)
                ]
            )
        ]
        return PresetStore(
            presets: samplePresets,
            onlineDisplays: sampleDisplays,
            isMirrored: false,
            activePresetName: "Studio Extended",
            isPreview: true
        )
    }

    public static var emptyPreview: PresetStore {
        PresetStore(
            presets: [],
            onlineDisplays: [],
            isMirrored: false,
            activePresetName: nil,
            isPreview: true
        )
    }
}
#endif

