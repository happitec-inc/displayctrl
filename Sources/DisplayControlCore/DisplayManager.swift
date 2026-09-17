// DisplayManager.swift
// Core display management functionality
//
// Integrates functionality from:
// - displaymode by Dean Scarff (Apache 2.0)
// - mirror-displays by Fabián Cañas (GPL-3.0)

import Foundation
import CoreGraphics

/// Central manager for querying displays, modifying resolutions, and configuring display mirroring on macOS.
///
/// `DisplayManager` wraps low-level CoreGraphics display configuration APIs (`CGDisplay`, `CGConfigureDisplayMirrorOfDisplay`,
/// and `CGConfigureDisplayWithDisplayMode`) with safe Swift abstractions, memory-managed opaque CoreFoundation bridging,
/// and full support for multi-monitor mirror topologies.
public final class DisplayManager: @unchecked Sendable {
    /// Shared singleton instance of `DisplayManager`.
    public static let shared = DisplayManager()

    /// Maximum number of displays supported for enumeration.
    private let maxDisplays: UInt32 = 32

    /// Tolerance in Hertz used when comparing requested and actual refresh rates.
    private let refreshTolerance: Double = 0.005

    private init() {}

    // MARK: - Display Information

    /// Retrieves a list of all online displays connected to the system, including mirror slaves.
    ///
    /// Unlike `CGGetActiveDisplayList`, which omits displays operating as mirror slaves, this method
    /// uses `CGGetOnlineDisplayList` to ensure every attached physical or virtual display is enumerated.
    ///
    /// - Returns: An array of ``DisplayInfo`` objects representing all online displays, each populated
    ///   with current mode, supported modes (sorted descending by resolution and refresh rate), and mirror relationships.
    /// - Throws: ``DisplayError/configurationFailed(_:)`` if CoreGraphics cannot query displays,
    ///   or ``DisplayError/noDisplays`` if no displays are online.
    public func getDisplays() throws -> [DisplayInfo] {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0

        let error = CGGetOnlineDisplayList(maxDisplays, &displayIDs, &displayCount)
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
            // CGDisplayIsInMirrorSet returns boolean_t (Int32), not Bool
            let isMirrored = CGDisplayIsInMirrorSet(displayID) != 0
            let rawMaster = CGDisplayMirrorsDisplay(displayID)
            let mirrorMasterID: UInt32? = rawMaster != 0 ? rawMaster : nil
            let serialNum = CGDisplaySerialNumber(displayID)
            let serialNumber: UInt32? = serialNum != 0 ? serialNum : nil

            // Get current mode
            guard let cgCurrentMode = CGDisplayCopyDisplayMode(displayID) else {
                continue
            }
            let currentMode = DisplayMode(from: cgCurrentMode, isCurrent: true)

            // Get all available modes.
            // CGDisplayCopyAllDisplayModes returns a CFArray of CGDisplayMode (a CF type).
            // CF types cannot be conditionally cast from AnyObject; bridge via CFArray directly.
            var availableModes: [DisplayMode] = []
            if let cfArray = CGDisplayCopyAllDisplayModes(displayID, nil) {
                let count = CFArrayGetCount(cfArray)
                availableModes = (0..<count).map { i in
                    let raw = CFArrayGetValueAtIndex(cfArray, i)!
                    let mode = Unmanaged<CGDisplayMode>.fromOpaque(raw).takeUnretainedValue()
                    return DisplayMode(from: mode, isCurrent: false)
                }
                // Sort by resolution descending, then refresh rate descending
                availableModes.sort {
                    if $0.width != $1.width { return $0.width > $1.width }
                    if $0.height != $1.height { return $0.height > $1.height }
                    return $0.refreshRate > $1.refreshRate
                }
            }

            let displayInfo = DisplayInfo(
                id: displayID,
                index: index,
                isMain: isMain,
                isMirrored: isMirrored,
                mirrorMasterID: mirrorMasterID,
                serialNumber: serialNumber,
                currentMode: currentMode,
                availableModes: availableModes
            )

            displays.append(displayInfo)
        }

        return displays
    }

    /// Retrieves information for a specific display identified by its zero-based enumeration index.
    ///
    /// - Parameter index: The zero-based display index (where 0 corresponds to the main display).
    /// - Returns: A tuple containing the CoreGraphics display identifier (`id`) and detailed ``DisplayInfo``.
    /// - Throws: ``DisplayError/displayNotFound(index:)`` if no online display matches the specified index.
    public func getDisplay(at index: UInt32) throws -> (id: CGDirectDisplayID, info: DisplayInfo) {
        let displays = try getDisplays()
        guard let display = displays.first(where: { $0.index == index }) else {
            throw DisplayError.displayNotFound(index: index)
        }
        return (display.id, display)
    }

    // MARK: - Mirroring (from mirror-displays)

    /// Checks whether any online display on the system is currently participating in a mirror set.
    ///
    /// This method checks all online displays, correctly detecting mirroring even if the primary
    /// main display is not the mirror master.
    ///
    /// - Returns: `true` if any display is in a mirror set; otherwise `false`.
    public func isMirrored() -> Bool {
        do {
            let displays = try getDisplays()
            return displays.contains { $0.isMirrored }
        } catch {
            return CGDisplayIsInMirrorSet(CGMainDisplayID()) != 0
        }
    }

    /// Enables mirroring for all secondary displays to the main display.
    ///
    /// Every non-main online display is configured to mirror the main display (`CGMainDisplayID()`),
    /// creating a complete hardware mirror set.
    ///
    /// - Throws: ``DisplayError/noDisplays`` if fewer than 2 displays are online, or
    ///   ``DisplayError/configurationFailed(_:)`` if the CoreGraphics configuration transaction fails.
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

    /// Disables mirroring across all displays, restoring extended desktop layout.
    ///
    /// Configures all mirrored secondary displays to detach from their mirror masters.
    ///
    /// - Throws: ``DisplayError/noDisplays`` if fewer than 2 displays are connected, or
    ///   ``DisplayError/configurationFailed(_:)`` if unmirroring cannot be applied.
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
            // kCGNullDirectDisplayID = 0 (use literal; constant removed from modern SDK)
            error = CGConfigureDisplayMirrorOfDisplay(config, secondaryID, 0)
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

    /// Toggles the global mirroring state on or off.
    ///
    /// If mirroring is active on any display, calls ``disableMirroring()``; otherwise calls ``enableMirroring()``.
    ///
    /// - Throws: ``DisplayError`` if display querying or configuration fails.
    public func toggleMirroring() throws {
        if isMirrored() {
            try disableMirroring()
        } else {
            try enableMirroring()
        }
    }

    /// Configures a specific slave display to mirror a designated master display by index.
    ///
    /// - Parameters:
    ///   - slaveIndex: Zero-based index of the display that should mirror the master.
    ///   - masterIndex: Zero-based index of the display to be mirrored.
    /// - Throws: ``DisplayError/displayNotFound(index:)`` if either display index is invalid, or
    ///   ``DisplayError/configurationFailed(_:)`` if applying the mirror link fails.
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

    /// Configures a specific slave display to mirror a designated master display using CoreGraphics display IDs directly.
    ///
    /// - Parameters:
    ///   - slaveID: The `CGDirectDisplayID` of the display that should mirror.
    ///   - masterID: The `CGDirectDisplayID` of the display to mirror.
    /// - Throws: ``DisplayError/configurationFailed(_:)`` if the configuration transaction fails.
    public func mirrorDisplayIDs(slave slaveID: CGDirectDisplayID, to masterID: CGDirectDisplayID) throws {
        var config: CGDisplayConfigRef?
        var error = CGBeginDisplayConfiguration(&config)
        guard error == .success, let config = config else {
            throw DisplayError.configurationFailed(error)
        }

        error = CGConfigureDisplayMirrorOfDisplay(config, slaveID, masterID)
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

    /// Sets the display resolution and optional refresh rate for a designated display.
    ///
    /// When `refreshRate` is omitted or set to `nil`, `DisplayManager` automatically selects the
    /// highest available refresh rate matching the target resolution.
    ///
    /// - Parameters:
    ///   - displayIndex: Zero-based index of the target display.
    ///   - width: Desired horizontal pixel resolution.
    ///   - height: Desired vertical pixel resolution.
    ///   - refreshRate: Optional target vertical refresh rate in Hz. If `nil`, the highest available rate is used.
    /// - Throws: ``DisplayError/displayNotFound(index:)`` if the display index is invalid,
    ///   ``DisplayError/modeNotFound(width:height:refreshRate:)`` if no supported mode matches,
    ///   or ``DisplayError/configurationFailed(_:)`` if CoreGraphics cannot switch to the mode.
    public func setMode(displayIndex: UInt32, width: Int, height: Int, refreshRate: Double? = nil) throws {
        let (displayID, displayInfo) = try getDisplay(at: displayIndex)

        // Find matching mode (pre-check; validates user-specified resolution is available)
        guard findMode(in: displayInfo.availableModes, width: width, height: height, refreshRate: refreshRate) != nil else {
            throw DisplayError.modeNotFound(width: width, height: height, refreshRate: refreshRate)
        }

        // Get all available CGDisplayModes to find the actual CGDisplayMode object to apply.
        // CGDisplayMode is a CF type — use Unmanaged.fromOpaque to extract from CFArray values.
        guard let cfArray = CGDisplayCopyAllDisplayModes(displayID, nil) else {
            throw DisplayError.invalidConfiguration
        }
        let modeCount = CFArrayGetCount(cfArray)
        var cgModes: [CGDisplayMode] = (0..<modeCount).map { i in
            let raw = CFArrayGetValueAtIndex(cfArray, i)!
            return Unmanaged<CGDisplayMode>.fromOpaque(raw).takeUnretainedValue()
        }
        // Prefer highest refresh rate when refresh rate is not specified
        cgModes.sort { $0.refreshRate > $1.refreshRate }

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
