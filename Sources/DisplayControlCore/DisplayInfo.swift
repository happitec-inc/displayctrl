// DisplayInfo.swift
// Core types for display information
//
// Based on displaymode by Dean Scarff (Apache 2.0)
// and mirror-displays by Fabián Cañas (GPL-3.0)

import Foundation
import CoreGraphics

/// Represents a display resolution and refresh rate mode.
///
/// `DisplayMode` wraps the properties of a CoreGraphics `CGDisplayMode`, capturing
/// the pixel width, pixel height, refresh rate in Hertz, and desktop usability flags.
public struct DisplayMode: Equatable, Codable, Sendable {
    /// The horizontal resolution of the display mode in points/pixels.
    public let width: Int

    /// The vertical resolution of the display mode in points/pixels.
    public let height: Int

    /// The vertical refresh rate of the display mode in Hertz (Hz).
    public let refreshRate: Double

    /// Indicates whether the mode is usable for standard macOS desktop graphical user interfaces.
    public let isUsableForDesktop: Bool

    /// Indicates whether this mode is the display's currently active mode.
    public let isCurrent: Bool

    /// Creates a new display mode representation.
    ///
    /// - Parameters:
    ///   - width: Horizontal resolution.
    ///   - height: Vertical resolution.
    ///   - refreshRate: Vertical refresh rate in Hz.
    ///   - isUsableForDesktop: Whether the mode is desktop GUI compatible (default: `true`).
    ///   - isCurrent: Whether this mode is currently active (default: `false`).
    public init(width: Int, height: Int, refreshRate: Double, isUsableForDesktop: Bool = true, isCurrent: Bool = false) {
        self.width = width
        self.height = height
        self.refreshRate = refreshRate
        self.isUsableForDesktop = isUsableForDesktop
        self.isCurrent = isCurrent
    }

    /// Creates a `DisplayMode` from a CoreGraphics `CGDisplayMode`.
    ///
    /// - Parameters:
    ///   - cgMode: The underlying CoreGraphics display mode.
    ///   - isCurrent: Whether this is the active display mode.
    init(from cgMode: CGDisplayMode, isCurrent: Bool = false) {
        self.width = cgMode.width
        self.height = cgMode.height
        self.refreshRate = cgMode.refreshRate
        self.isUsableForDesktop = cgMode.isUsableForDesktopGUI()
        self.isCurrent = isCurrent
    }

    /// Formats the display mode as a human-readable string (e.g. `"1920x1080@60Hz"` or `"1920x1080"`).
    public var description: String {
        if refreshRate > 0 {
            return "\(width)x\(height)@\(Int(refreshRate))Hz"
        } else {
            return "\(width)x\(height)"
        }
    }
}

/// Represents a connected physical or virtual display device on macOS.
///
/// `DisplayInfo` encapsulates the display ID, enumeration index, main display flag,
/// mirror relationship, hardware serial number, active mode, and all supported display modes.
public struct DisplayInfo: Identifiable, Codable, Sendable {
    /// The unique CoreGraphics display identifier (`CGDirectDisplayID`).
    public let id: UInt32

    /// The zero-based enumeration index of the display in the system's online display list.
    public let index: UInt32

    /// Indicates whether this display is the primary macOS main display (`CGMainDisplayID()`).
    public let isMain: Bool

    /// Indicates whether this display participates in a mirror set as either master or mirror slave.
    public let isMirrored: Bool

    /// The display identifier of the master display if this display is mirroring another, or `nil` if not mirrored.
    public let mirrorMasterID: UInt32?

    /// The hardware serial number reported by EDID (`CGDisplaySerialNumber`), if available.
    public let serialNumber: UInt32?

    /// The currently active resolution and refresh rate mode on the display.
    public let currentMode: DisplayMode?

    /// All available display modes supported by this display, sorted by resolution and refresh rate descending.
    public let availableModes: [DisplayMode]

    /// Creates a new `DisplayInfo` instance.
    ///
    /// - Parameters:
    ///   - id: The CoreGraphics display identifier.
    ///   - index: Zero-based enumeration index.
    ///   - isMain: Whether this is the main display.
    ///   - isMirrored: Whether this display is in a mirror set.
    ///   - mirrorMasterID: The master display ID if mirrored.
    ///   - serialNumber: Hardware serial number if available.
    ///   - currentMode: Active display mode.
    ///   - availableModes: Array of supported display modes.
    public init(
        id: UInt32,
        index: UInt32,
        isMain: Bool,
        isMirrored: Bool,
        mirrorMasterID: UInt32? = nil,
        serialNumber: UInt32? = nil,
        currentMode: DisplayMode?,
        availableModes: [DisplayMode]
    ) {
        self.id = id
        self.index = index
        self.isMain = isMain
        self.isMirrored = isMirrored
        self.mirrorMasterID = mirrorMasterID
        self.serialNumber = serialNumber
        self.currentMode = currentMode
        self.availableModes = availableModes
    }
}

/// Error types thrown during display querying, configuration, or resolution switching operations.
public enum DisplayError: Error, LocalizedError, Sendable {
    /// No online displays were detected by CoreGraphics.
    case noDisplays

    /// A display with the requested enumeration index could not be found.
    case displayNotFound(index: UInt32)

    /// A display mode matching the requested resolution and refresh rate could not be located.
    case modeNotFound(width: Int, height: Int, refreshRate: Double?)

    /// A CoreGraphics display configuration transaction failed with the specified error code.
    case configurationFailed(CGError)

    /// The display configuration or mode parameters are invalid.
    case invalidConfiguration

    /// A localized description of the error suitable for display to users.
    public var errorDescription: String? {
        switch self {
        case .noDisplays:
            return "No displays detected"
        case .displayNotFound(let index):
            return "Display at index \(index) not found"
        case .modeNotFound(let width, let height, let refreshRate):
            if let refresh = refreshRate {
                return "Mode \(width)x\(height)@\(refresh)Hz not found"
            } else {
                return "Mode \(width)x\(height) not found"
            }
        case .configurationFailed(let error):
            return "Display configuration failed with error: \(error)"
        case .invalidConfiguration:
            return "Invalid display configuration"
        }
    }
}
