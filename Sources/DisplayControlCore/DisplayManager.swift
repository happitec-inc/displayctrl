// DisplayManager.swift
// Core display management functionality
//
// Integrates functionality from:
// - displaymode by Dean Scarff (Apache 2.0)
// - mirror-displays by Fabián Cañas (GPL-3.0)

import Foundation
import CoreGraphics

/// Main interface for managing displays
public class DisplayManager {
    public static let shared = DisplayManager()

    private let maxDisplays: UInt32 = 32
    private let refreshTolerance: Double = 0.005

    private init() {}

    // MARK: - Display Information

    /// Get all active displays
    public func getDisplays() throws -> [DisplayInfo] {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0

        let error = CGGetActiveDisplayList(maxDisplays, &displayIDs, &displayCount)
        guard error == .success else {
            throw DisplayError.configurationFailed(error)
        }

        guard displayCount > 0 else {
            throw DisplayError.noDisplays
        }

        let mainDisplayID = CGMainDisplayID()
        var displays: [DisplayInfo] = []

        for index in 0..<displayCount {
            let displayID = displayIDs[Int(index)]
            let isMain = displayID == mainDisplayID
            let isMirrored = CGDisplayIsInMirrorSet(displayID)

            // Get current mode
            guard let cgCurrentMode = CGDisplayCopyDisplayMode(displayID) else {
                continue
            }
            let currentMode = DisplayMode(from: cgCurrentMode, isCurrent: true)

            // Get all available modes
            guard let cgModes = CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode] else {
                continue
            }

            let availableModes = cgModes.map { mode in
                DisplayMode(from: mode, isCurrent: false)
            }

            let displayInfo = DisplayInfo(
                id: displayID,
                index: index,
                isMain: isMain,
                isMirrored: isMirrored,
                currentMode: currentMode,
                availableModes: availableModes
            )

            displays.append(displayInfo)
        }

        return displays
    }

    /// Get a specific display by index
    public func getDisplay(at index: UInt32) throws -> (id: CGDirectDisplayID, info: DisplayInfo) {
        let displays = try getDisplays()
        guard let display = displays.first(where: { $0.index == index }) else {
            throw DisplayError.displayNotFound(index: index)
        }
        return (display.id, display)
    }

    // MARK: - Mirroring (from mirror-displays)

    /// Check if displays are currently mirrored
    public func isMirrored() -> Bool {
        return CGDisplayIsInMirrorSet(CGMainDisplayID())
    }

    /// Enable mirroring for all secondary displays to the main display
    public func enableMirroring() throws {
        let displays = try getDisplays()
        guard displays.count >= 2 else {
            throw DisplayError.noDisplays
        }

        let mainDisplayID = CGMainDisplayID()
        let secondaryDisplayIDs = displays
            .filter { $0.id != mainDisplayID }
            .map { $0.id }

        var config: CGDisplayConfigRef?
        var error = CGBeginDisplayConfiguration(&config)
        guard error == .success, let config = config else {
            throw DisplayError.configurationFailed(error)
        }

        // Mirror all secondary displays to the main display
        for secondaryID in secondaryDisplayIDs {
            error = CGConfigureDisplayMirrorOfDisplay(config, secondaryID, mainDisplayID)
            guard error == .success else {
                CGCancelDisplayConfiguration(config)
                throw DisplayError.configurationFailed(error)
            }
        }

        error = CGCompleteDisplayConfiguration(config, .permanently)
        guard error == .success else {
            throw DisplayError.configurationFailed(error)
        }
    }

    /// Disable mirroring for all displays
    public func disableMirroring() throws {
        let displays = try getDisplays()
        guard displays.count >= 2 else {
            throw DisplayError.noDisplays
        }

        let mainDisplayID = CGMainDisplayID()
        let secondaryDisplayIDs = displays
            .filter { $0.id != mainDisplayID }
            .map { $0.id }

        var config: CGDisplayConfigRef?
        var error = CGBeginDisplayConfiguration(&config)
        guard error == .success, let config = config else {
            throw DisplayError.configurationFailed(error)
        }

        // Unmirror all secondary displays
        for secondaryID in secondaryDisplayIDs {
            error = CGConfigureDisplayMirrorOfDisplay(config, secondaryID, kCGNullDirectDisplayID)
            guard error == .success else {
                CGCancelDisplayConfiguration(config)
                throw DisplayError.configurationFailed(error)
            }
        }

        error = CGCompleteDisplayConfiguration(config, .permanently)
        guard error == .success else {
            throw DisplayError.configurationFailed(error)
        }
    }

    /// Toggle mirroring state
    public func toggleMirroring() throws {
        if isMirrored() {
            try disableMirroring()
        } else {
            try enableMirroring()
        }
    }

    /// Mirror a specific display to another
    public func mirrorDisplay(slave slaveIndex: UInt32, to masterIndex: UInt32) throws {
        let displays = try getDisplays()

        guard let masterDisplay = displays.first(where: { $0.index == masterIndex }) else {
            throw DisplayError.displayNotFound(index: masterIndex)
        }

        guard let slaveDisplay = displays.first(where: { $0.index == slaveIndex }) else {
            throw DisplayError.displayNotFound(index: slaveIndex)
        }

        var config: CGDisplayConfigRef?
        var error = CGBeginDisplayConfiguration(&config)
        guard error == .success, let config = config else {
            throw DisplayError.configurationFailed(error)
        }

        error = CGConfigureDisplayMirrorOfDisplay(config, slaveDisplay.id, masterDisplay.id)
        guard error == .success else {
            CGCancelDisplayConfiguration(config)
            throw DisplayError.configurationFailed(error)
        }

        error = CGCompleteDisplayConfiguration(config, .permanently)
        guard error == .success else {
            throw DisplayError.configurationFailed(error)
        }
    }

    // MARK: - Resolution Management (from displaymode)

    /// Set the display mode for a specific display
    public func setMode(displayIndex: UInt32, width: Int, height: Int, refreshRate: Double? = nil) throws {
        let (displayID, displayInfo) = try getDisplay(at: displayIndex)

        // Find matching mode
        guard let matchingMode = findMode(in: displayInfo.availableModes, width: width, height: height, refreshRate: refreshRate) else {
            throw DisplayError.modeNotFound(width: width, height: height, refreshRate: refreshRate)
        }

        // Get all available CGDisplayModes to find the actual mode object
        guard let cgModes = CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode] else {
            throw DisplayError.invalidConfiguration
        }

        guard let cgMode = cgModes.first(where: { mode in
            mode.width == width &&
            mode.height == height &&
            matchesRefreshRate(specified: refreshRate ?? 0.0, actual: mode.refreshRate)
        }) else {
            throw DisplayError.modeNotFound(width: width, height: height, refreshRate: refreshRate)
        }

        // Apply the mode
        var config: CGDisplayConfigRef?
        var error = CGBeginDisplayConfiguration(&config)
        guard error == .success, let config = config else {
            throw DisplayError.configurationFailed(error)
        }

        error = CGConfigureDisplayWithDisplayMode(config, displayID, cgMode, nil)
        guard error == .success else {
            CGCancelDisplayConfiguration(config)
            throw DisplayError.configurationFailed(error)
        }

        error = CGCompleteDisplayConfiguration(config, .permanently)
        guard error == .success else {
            throw DisplayError.configurationFailed(error)
        }
    }

    // MARK: - Helper Methods

    private func findMode(in modes: [DisplayMode], width: Int, height: Int, refreshRate: Double?) -> DisplayMode? {
        return modes.first { mode in
            mode.width == width &&
            mode.height == height &&
            matchesRefreshRate(specified: refreshRate ?? 0.0, actual: mode.refreshRate)
        }
    }

    private func matchesRefreshRate(specified: Double, actual: Double) -> Bool {
        return specified == 0.0 || abs(specified - actual) < refreshTolerance
    }
}
