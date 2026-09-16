// Configuration.swift
// Support for named display configurations
//
// Part of DisplayControl
// Licensed under GPL-3.0 (due to mirror-displays integration)

import Foundation

/// A named display configuration
public struct DisplayConfiguration: Codable, Equatable {
    public let name: String
    public let mirroring: MirroringConfig
    public let displays: [DisplayConfig]

    public init(name: String, mirroring: MirroringConfig, displays: [DisplayConfig]) {
        self.name = name
        self.mirroring = mirroring
        self.displays = displays
    }

    public enum MirroringConfig: String, Codable {
        case enabled
        case disabled
        case unchanged
    }

    public struct DisplayConfig: Codable, Equatable {
        public let index: UInt32
        public let width: Int?
        public let height: Int?
        public let refreshRate: Double?

        public init(index: UInt32, width: Int? = nil, height: Int? = nil, refreshRate: Double? = nil) {
            self.index = index
            self.width = width
            self.height = height
            self.refreshRate = refreshRate
        }
    }
}

/// Manages display configuration files
public class ConfigurationManager {
    public static let shared = ConfigurationManager()

    private let configDirectory: URL
    private let configFileName = "displayconfigs.json"

    private init() {
        // Use Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        configDirectory = appSupport.appendingPathComponent("DisplayControl", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
    }

    public var configFileURL: URL {
        return configDirectory.appendingPathComponent(configFileName)
    }

    /// Load all configurations from file
    public func loadConfigurations() throws -> [DisplayConfiguration] {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: configFileURL)
        let decoder = JSONDecoder()
        return try decoder.decode([DisplayConfiguration].self, from: data)
    }

    /// Save configurations to file
    public func saveConfigurations(_ configurations: [DisplayConfiguration]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configurations)
        try data.write(to: configFileURL)
    }

    /// Get a specific configuration by name
    public func getConfiguration(named name: String) throws -> DisplayConfiguration? {
        let configurations = try loadConfigurations()
        return configurations.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Add or update a configuration
    public func saveConfiguration(_ configuration: DisplayConfiguration) throws {
        var configurations = try loadConfigurations()

        // Remove existing configuration with the same name
        configurations.removeAll { $0.name.lowercased() == configuration.name.lowercased() }

        // Add new configuration
        configurations.append(configuration)

        try saveConfigurations(configurations)
    }

    /// Delete a configuration by name
    public func deleteConfiguration(named name: String) throws {
        var configurations = try loadConfigurations()
        configurations.removeAll { $0.name.lowercased() == name.lowercased() }
        try saveConfigurations(configurations)
    }

    /// Apply a named configuration
    public func applyConfiguration(named name: String) throws {
        guard let config = try getConfiguration(named: name) else {
            throw ConfigurationError.notFound(name)
        }

        try applyConfiguration(config)
    }

    /// Apply a configuration
    public func applyConfiguration(_ config: DisplayConfiguration) throws {
        let manager = DisplayManager.shared

        // Apply mirroring first
        switch config.mirroring {
        case .enabled:
            try manager.enableMirroring()
        case .disabled:
            try manager.disableMirroring()
        case .unchanged:
            break
        }

        // Apply display modes
        for displayConfig in config.displays {
            if let width = displayConfig.width,
               let height = displayConfig.height {
                try manager.setMode(
                    displayIndex: displayConfig.index,
                    width: width,
                    height: height,
                    refreshRate: displayConfig.refreshRate
                )
            }
        }
    }

    /// Capture the current display configuration
    public func captureCurrentConfiguration(name: String) throws -> DisplayConfiguration {
        let manager = DisplayManager.shared
        let displays = try manager.getDisplays()

        let mirroring: DisplayConfiguration.MirroringConfig = manager.isMirrored() ? .enabled : .disabled

        let displayConfigs = displays.compactMap { display -> DisplayConfiguration.DisplayConfig? in
            guard let currentMode = display.currentMode else { return nil }
            return DisplayConfiguration.DisplayConfig(
                index: display.index,
                width: currentMode.width,
                height: currentMode.height,
                refreshRate: currentMode.refreshRate
            )
        }

        return DisplayConfiguration(
            name: name,
            mirroring: mirroring,
            displays: displayConfigs
        )
    }

    /// Create a sample configuration file with examples.
    /// If force is false and configurations already exist, throws ConfigurationError.alreadyExists.
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

public enum ConfigurationError: Error, LocalizedError {
    case notFound(String)
    case invalidFormat
    case alreadyExists

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
