// DisplayInfo.swift
// Core types for display information
//
// Based on displaymode by Dean Scarff (Apache 2.0)
// and mirror-displays by Fabián Cañas (GPL-3.0)

import Foundation
import CoreGraphics

/// Represents a display mode with resolution and refresh rate
public struct DisplayMode: Equatable, Codable {
    public let width: Int
    public let height: Int
    public let refreshRate: Double
    public let isUsableForDesktop: Bool
    public let isCurrent: Bool

    public init(width: Int, height: Int, refreshRate: Double, isUsableForDesktop: Bool = true, isCurrent: Bool = false) {
        self.width = width
        self.height = height
        self.refreshRate = refreshRate
        self.isUsableForDesktop = isUsableForDesktop
        self.isCurrent = isCurrent
    }

    /// Create from a CGDisplayMode
    init(from cgMode: CGDisplayMode, isCurrent: Bool = false) {
        self.width = cgMode.width
        self.height = cgMode.height
        self.refreshRate = cgMode.refreshRate
        self.isUsableForDesktop = cgMode.isUsableForDesktopGUI
        self.isCurrent = isCurrent
    }

    /// Format as a string like "1920x1080@60Hz"
    public var description: String {
        if refreshRate > 0 {
            return "\(width)x\(height)@\(Int(refreshRate))Hz"
        } else {
            return "\(width)x\(height)"
        }
    }
}

/// Represents a display device
public struct DisplayInfo: Identifiable, Codable {
    public let id: UInt32
    public let index: UInt32
    public let isMain: Bool
    public let isMirrored: Bool
    public let currentMode: DisplayMode?
    public let availableModes: [DisplayMode]

    public init(id: UInt32, index: UInt32, isMain: Bool, isMirrored: Bool, currentMode: DisplayMode?, availableModes: [DisplayMode]) {
        self.id = id
        self.index = index
        self.isMain = isMain
        self.isMirrored = isMirrored
        self.currentMode = currentMode
        self.availableModes = availableModes
    }
}

/// Error types for display operations
public enum DisplayError: Error, LocalizedError {
    case noDisplays
    case displayNotFound(index: UInt32)
    case modeNotFound(width: Int, height: Int, refreshRate: Double?)
    case configurationFailed(CGError)
    case invalidConfiguration

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
