// Configuration.swift
// Support for named display configurations
//
// Part of DisplayControl
// Licensed under GPL-3.0 (due to mirror-displays integration)

import Foundation

/// A persistent named display configuration profile.
///
/// `DisplayConfiguration` captures a complete snapshot of display states:
/// global or topological mirroring arrangements, hardware serial numbers, resolutions,
/// and refresh rates for all connected monitors.
public struct DisplayConfiguration: Codable, Equatable, Sendable {
    /// Unique name of the configuration profile (e.g. `"ipad"`, `"presentation"`, `"extended"`).
    public let name: String

    /// Global mirroring directive applied when fine-grained topological linkages are absent.
    public let mirroring: MirroringConfig

    /// Per-display mode configurations and mirror topology bindings.
    public let displays: [DisplayConfig]

    /// Creates a new named display configuration profile.
    ///
    /// - Parameters:
    ///   - name: Unique configuration name.
    ///   - mirroring: Overall mirroring policy.
    ///   - displays: Array of per-display configuration settings.
    public init(name: String, mirroring: MirroringConfig, displays: [DisplayConfig]) {
        self.name = name
        self.mirroring = mirroring
        self.displays = displays
    }

    /// Global display mirroring policies.
    public enum MirroringConfig: String, Codable, Sendable {
        /// Enable mirroring across all secondary monitors to the main display.
        case enabled

        /// Disable mirroring and restore extended desktop layout.
        case disabled

        /// Leave the current mirroring arrangement unmodified when applying modes.
        case unchanged
    }

    /// Configuration parameters for a single display device within a profile.
    public struct DisplayConfig: Codable, Equatable, Sendable {
        /// Zero-based enumeration index of the display.
        public let index: UInt32

        /// Hardware EDID serial number used to stably match displays across reboots and dock disconnects.
        public let serialNumber: UInt32?

        /// Target horizontal resolution in pixels, or `nil` to leave unmodified.
        public let width: Int?

        /// Target vertical resolution in pixels, or `nil` to leave unmodified.
        public let height: Int?

        /// Target refresh rate in Hz, or `nil` to automatically select the highest available rate.
        public let refreshRate: Double?

        /// Enumeration index of the master display to mirror, if this display is a mirror slave.
        public let mirrorMasterIndex: UInt32?

        /// Hardware serial number of the master display to mirror, if this display is a mirror slave.
        public let mirrorMasterSerial: UInt32?

        /// Creates a display configuration entry.
        ///
        /// - Parameters:
        ///   - index: Zero-based enumeration index.
        ///   - serialNumber: Hardware serial number for stable matching.
        ///   - width: Desired pixel width.
        ///   - height: Desired pixel height.
        ///   - refreshRate: Desired refresh rate in Hz.
        ///   - mirrorMasterIndex: Index of mirror master display if mirrored.
        ///   - mirrorMasterSerial: Serial number of mirror master display if mirrored.
        public init(
            index: UInt32,
            serialNumber: UInt32? = nil,
            width: Int? = nil,
            height: Int? = nil,
            refreshRate: Double? = nil,
            mirrorMasterIndex: UInt32? = nil,
            mirrorMasterSerial: UInt32? = nil
        ) {
            self.index = index
            self.serialNumber = serialNumber
            self.width = width
            self.height = height
            self.refreshRate = refreshRate
            self.mirrorMasterIndex = mirrorMasterIndex
            self.mirrorMasterSerial = mirrorMasterSerial
        }
    }
}

/// Manages loading, saving, querying, applying, and deleting named display configuration files on disk.
///
/// Configurations are persisted in JSON format at `~/Library/Application Support/DisplayControl/displayconfigs.json`
/// by default, but custom file URLs can be provided for hermetic testing.
public final class ConfigurationManager: @unchecked Sendable {
    /// Shared singleton instance pointing to user Application Support storage.
    public static let shared = ConfigurationManager()

    /// The filesystem URL where configuration JSON profiles are saved.
    public let configFileURL: URL

    /// Initializes a configuration manager with an optional custom file URL.
    ///
    /// - Parameter configFileURL: Target file URL for configuration storage. If `nil`, defaults
    ///   to `~/Library/Application Support/DisplayControl/displayconfigs.json`.
    public init(configFileURL: URL? = nil) {
        if let fileURL = configFileURL {
            self.configFileURL = fileURL
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } else {
            // Use Application Support directory
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let configDirectory = appSupport.appendingPathComponent("DisplayControl", isDirectory: true)
            self.configFileURL = configDirectory.appendingPathComponent("displayconfigs.json")
            try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }
    }

    /// Loads all saved configuration profiles from the JSON storage file.
    ///
    /// - Returns: An array of ``DisplayConfiguration`` profiles, or an empty array if the file does not yet exist.
    /// - Throws: An error if file reading or JSON deserialization fails.
    public func loadConfigurations() throws -> [DisplayConfiguration] {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: configFileURL)
        let decoder = JSONDecoder()
        return try decoder.decode([DisplayConfiguration].self, from: data)
    }

    /// Serializes and writes an array of configuration profiles to the JSON storage file.
    ///
    /// - Parameter configurations: Array of profiles to persist.
    /// - Throws: An error if JSON encoding or filesystem writing fails.
    public func saveConfigurations(_ configurations: [DisplayConfiguration]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configurations)
        try data.write(to: configFileURL)
    }

    /// Retrieves a specific saved configuration profile by its case-insensitive name.
    ///
    /// - Parameter name: Name of the profile to find.
    /// - Returns: The matching ``DisplayConfiguration``, or `nil` if not found.
    /// - Throws: An error if the configuration file cannot be read.
    public func getConfiguration(named name: String) throws -> DisplayConfiguration? {
        let configurations = try loadConfigurations()
        return configurations.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Adds or updates a configuration profile. If a profile with the same case-insensitive name exists, it is replaced.
    ///
    /// - Parameter configuration: The configuration profile to save.
    /// - Throws: An error if file I/O or JSON encoding fails.
    public func saveConfiguration(_ configuration: DisplayConfiguration) throws {
        var configurations = try loadConfigurations()

        // Remove existing configuration with the same name
        configurations.removeAll { $0.name.lowercased() == configuration.name.lowercased() }

        // Add new configuration
        configurations.append(configuration)

        try saveConfigurations(configurations)
    }

    /// Deletes a saved configuration profile by name.
    ///
    /// - Parameter name: Name of the configuration profile to remove.
    /// - Throws: An error if persisting the updated configuration list fails.
    public func deleteConfiguration(named name: String) throws {
        var configurations = try loadConfigurations()
        configurations.removeAll { $0.name.lowercased() == name.lowercased() }
        try saveConfigurations(configurations)
    }

    /// Applies a saved configuration profile identified by name.
    ///
    /// - Parameter name: Name of the configuration profile to apply.
    /// - Throws: ``ConfigurationError/notFound(_:)`` if no profile with that name exists,
    ///   or ``DisplayError`` if display mode switching or mirroring configuration fails.
    public func applyConfiguration(named name: String) throws {
        guard let config = try getConfiguration(named: name) else {
            throw ConfigurationError.notFound(name)
        }

        try applyConfiguration(config)
    }

    /// Applies a configuration profile to online displays.
    ///
    /// Displays are resolved using hardware serial numbers first, falling back to enumeration indices.
    /// If specific mirror pairs (`mirrorMasterSerial` or `mirrorMasterIndex`) are specified, topological
    /// links are restored; otherwise global mirroring policies are applied.
    ///
    /// - Parameter config: The ``DisplayConfiguration`` profile to apply.
    /// - Throws: ``DisplayError`` if CoreGraphics display mode switching or mirroring fails.
    public func applyConfiguration(_ config: DisplayConfiguration) throws {
        let manager = DisplayManager.shared
        let onlineDisplays = try manager.getDisplays()

        // Helper to resolve a display from config by serial number first, falling back to index
        func resolveDisplay(_ displayConfig: DisplayConfiguration.DisplayConfig) -> DisplayInfo? {
            if let serial = displayConfig.serialNumber,
               let match = onlineDisplays.first(where: { $0.serialNumber == serial }) {
                return match
            }
            return onlineDisplays.first(where: { $0.index == displayConfig.index })
        }

        // Check if fine-grained mirror topology is defined in the config
        let hasSpecificMirrorPairs = config.displays.contains { $0.mirrorMasterIndex != nil || $0.mirrorMasterSerial != nil }

        if hasSpecificMirrorPairs {
            // First unmirror to achieve a clean baseline
            try? manager.disableMirroring()

            for displayConfig in config.displays {
                guard let slave = resolveDisplay(displayConfig) else { continue }

                // Find target master display by serial number first, then index
                var targetMaster: DisplayInfo? = nil
                if let masterSerial = displayConfig.mirrorMasterSerial {
                    targetMaster = onlineDisplays.first { $0.serialNumber == masterSerial }
                }
                if targetMaster == nil, let masterIdx = displayConfig.mirrorMasterIndex {
                    targetMaster = onlineDisplays.first { $0.index == masterIdx }
                }

                if let master = targetMaster {
                    try manager.mirrorDisplayIDs(slave: slave.id, to: master.id)
                }
            }
        } else {
            // Apply global mirroring setting
            switch config.mirroring {
            case .enabled:
                try manager.enableMirroring()
            case .disabled:
                try manager.disableMirroring()
            case .unchanged:
                break
            }
        }

        // Apply display modes to resolved displays
        for displayConfig in config.displays {
            guard let display = resolveDisplay(displayConfig) else { continue }
            if let width = displayConfig.width,
               let height = displayConfig.height {
                try manager.setMode(
                    displayIndex: display.index,
                    width: width,
                    height: height,
                    refreshRate: displayConfig.refreshRate
                )
            }
        }
    }

    /// Captures the current live display configuration into a new profile snapshot.
    ///
    /// Records display modes, refresh rates, hardware serial numbers, and mirror topology relationships.
    ///
    /// - Parameter name: Name to assign to the captured configuration.
    /// - Returns: A ``DisplayConfiguration`` profile reflecting the active display setup.
    /// - Throws: ``DisplayError`` if querying online displays fails.
    public func captureCurrentConfiguration(name: String) throws -> DisplayConfiguration {
        let manager = DisplayManager.shared
        let displays = try manager.getDisplays()

        let mirroring: DisplayConfiguration.MirroringConfig = manager.isMirrored() ? .enabled : .disabled

        let displayConfigs = displays.compactMap { display -> DisplayConfiguration.DisplayConfig? in
            guard let currentMode = display.currentMode else { return nil }

            // Resolve mirror master info if mirrored
            var masterIndex: UInt32? = nil
            var masterSerial: UInt32? = nil
            if let masterID = display.mirrorMasterID,
               let masterDisplay = displays.first(where: { $0.id == masterID }) {
                masterIndex = masterDisplay.index
                masterSerial = masterDisplay.serialNumber
            }

            return DisplayConfiguration.DisplayConfig(
                index: display.index,
                serialNumber: display.serialNumber,
                width: currentMode.width,
                height: currentMode.height,
                refreshRate: currentMode.refreshRate,
                mirrorMasterIndex: masterIndex,
                mirrorMasterSerial: masterSerial
            )
        }

        return DisplayConfiguration(
            name: name,
            mirroring: mirroring,
            displays: displayConfigs
        )
    }

    /// Creates a sample configuration file containing example profiles (`ipad`, `presentation`, `extended`).
    ///
    /// - Parameter force: If `true`, overwrites existing configurations. If `false` and profiles already exist,
    ///   throws ``ConfigurationError/alreadyExists``.
    /// - Throws: ``ConfigurationError/alreadyExists`` if profiles exist and `force` is `false`,
    ///   or a filesystem error if writing fails.
    public func createSampleConfiguration(force: Bool = false) throws {
        let existing = (try? loadConfigurations()) ?? []
        if !existing.isEmpty && !force {
            throw ConfigurationError.alreadyExists
        }

        let sampleConfigs = [
            DisplayConfiguration(
                name: "ipad",
                mirroring: .enabled,
                displays: [
                    DisplayConfiguration.DisplayConfig(
                        index: 0,
                        width: 1600,
                        height: 1200,
                        refreshRate: 60
                    )
                ]
            ),
            DisplayConfiguration(
                name: "presentation",
                mirroring: .enabled,
                displays: [
                    DisplayConfiguration.DisplayConfig(
                        index: 0,
                        width: 1920,
                        height: 1080,
                        refreshRate: 60
                    )
                ]
            ),
            DisplayConfiguration(
                name: "extended",
                mirroring: .disabled,
                displays: [
                    DisplayConfiguration.DisplayConfig(
                        index: 0,
                        width: 2560,
                        height: 1440,
                        refreshRate: nil
                    ),
                    DisplayConfiguration.DisplayConfig(
                        index: 1,
                        width: 1920,
                        height: 1080,
                        refreshRate: nil
                    )
                ]
            )
        ]

        if force {
            try saveConfigurations(sampleConfigs)
        } else {
            // If file doesn't exist or is empty, save sample configs
            try saveConfigurations(sampleConfigs)
        }
    }
}

/// Error types thrown during display profile management.
public enum ConfigurationError: Error, LocalizedError, Sendable {
    /// A configuration with the requested profile name could not be found.
    case notFound(String)

    /// The configuration file contains invalid or corrupted data.
    case invalidFormat

    /// The configuration file already exists and contains profiles; explicit overwrite confirmation is required.
    case alreadyExists

    /// A localized description of the error suitable for user presentation.
    public var errorDescription: String? {
        switch self {
        case .notFound(let name):
            return "Configuration '\(name)' not found"
        case .invalidFormat:
            return "Invalid configuration format"
        case .alreadyExists:
            return "Configuration file already exists and contains profiles. Use --force to overwrite."
        }
    }
}
