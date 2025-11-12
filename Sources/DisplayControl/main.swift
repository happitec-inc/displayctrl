// main.swift
// Command-line interface for DisplayControl
//
// Combines functionality from:
// - displaymode by Dean Scarff (Apache 2.0)
// - mirror-displays by Fabián Cañas (GPL-3.0)
//
// This program is licensed under GPL-3.0

import Foundation
import DisplayControlCore

let version = "1.0.0"

func printUsage() {
    print("""
    DisplayControl v\(version)
    A unified tool for managing display mirroring and resolution on macOS

    Based on:
    - displaymode by Dean Scarff (Apache 2.0)
    - mirror-displays by Fabián Cañas (GPL-3.0)

    USAGE:
        displayctl [command] [options]

    COMMANDS:
        list, ls                    List all displays and their current modes
        mirror on                   Enable mirroring (all displays mirror main)
        mirror off                  Disable mirroring
        mirror toggle               Toggle mirroring state
        mirror status               Show current mirroring status
        mirror link <slave> <master> Make display <slave> mirror display <master>

        resolution set <display> <width> <height> [refresh]
                                    Set resolution for a specific display
                                    Display is 0-indexed (0 = main display)
                                    Refresh rate is optional (e.g., 60)

        config list                 List all saved configurations
        config show <name>          Show details of a configuration
        config save <name>          Save current setup as a named configuration
        config apply <name>         Apply a named configuration
        config delete <name>        Delete a configuration
        config init                 Create sample configuration file
        config path                 Show configuration file path

        help, -h, --help            Show this help message
        version, -v, --version      Show version information

    EXAMPLES:
        # List all displays
        displayctl list

        # Enable mirroring
        displayctl mirror on

        # Set main display to 1920x1080 at 60Hz
        displayctl resolution set 0 1920 1080 60

        # Save current configuration as "ipad"
        displayctl config save ipad

        # Apply the "ipad" configuration
        displayctl config apply ipad
    """)
}

func printVersion() {
    print("""
    DisplayControl v\(version)

    Based on:
    - displaymode v1.4.0, Copyright 2019-2023 Dean Scarff (Apache 2.0)
    - mirror-displays v1.2, Copyright 2009-2018 Fabián Cañas (GPL-3.0)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    """)
}

func handleError(_ error: Error) {
    if let displayError = error as? DisplayError {
        print("Error: \(displayError.localizedDescription)")
    } else if let configError = error as? ConfigurationError {
        print("Error: \(configError.localizedDescription)")
    } else {
        print("Error: \(error.localizedDescription)")
    }
    exit(1)
}

// MARK: - Command Handlers

func listDisplays() {
    do {
        let manager = DisplayManager.shared
        let displays = try manager.getDisplays()

        print("Found \(displays.count) display(s):\n")

        for display in displays {
            let mainTag = display.isMain ? " (MAIN)" : ""
            let mirrorTag = display.isMirrored ? " [MIRRORED]" : ""
            print("Display \(display.index)\(mainTag)\(mirrorTag):")

            if let currentMode = display.currentMode {
                print("  Current: \(currentMode.description)")
            }

            print("  Available modes:")
            let sortedModes = display.availableModes
                .filter { $0.isUsableForDesktop }
                .sorted { ($0.width, $0.height) > ($1.width, $1.height) }

            for mode in sortedModes {
                let current = mode == display.currentMode ? " *" : ""
                print("    \(mode.description)\(current)")
            }
            print()
        }
    } catch {
        handleError(error)
    }
}

func handleMirrorCommand(_ args: [String]) {
    guard args.count >= 1 else {
        print("Error: Missing mirror subcommand")
        print("Usage: displayctl mirror [on|off|toggle|status|link]")
        exit(1)
    }

    let manager = DisplayManager.shared

    do {
        switch args[0] {
        case "on":
            try manager.enableMirroring()
            print("Mirroring enabled")

        case "off":
            try manager.disableMirroring()
            print("Mirroring disabled")

        case "toggle":
            try manager.toggleMirroring()
            let state = manager.isMirrored() ? "enabled" : "disabled"
            print("Mirroring \(state)")

        case "status":
            let state = manager.isMirrored() ? "on" : "off"
            print(state)

        case "link":
            guard args.count >= 3 else {
                print("Error: Missing arguments for mirror link")
                print("Usage: displayctl mirror link <slave_index> <master_index>")
                exit(1)
            }
            guard let slaveIndex = UInt32(args[1]),
                  let masterIndex = UInt32(args[2]) else {
                print("Error: Invalid display indices")
                exit(1)
            }
            try manager.mirrorDisplay(slave: slaveIndex, to: masterIndex)
            print("Display \(slaveIndex) now mirrors display \(masterIndex)")

        default:
            print("Error: Unknown mirror subcommand '\(args[0])'")
            print("Valid subcommands: on, off, toggle, status, link")
            exit(1)
        }
    } catch {
        handleError(error)
    }
}

func handleResolutionCommand(_ args: [String]) {
    guard args.count >= 1 else {
        print("Error: Missing resolution subcommand")
        print("Usage: displayctl resolution set <display> <width> <height> [refresh]")
        exit(1)
    }

    guard args[0] == "set" else {
        print("Error: Unknown resolution subcommand '\(args[0])'")
        exit(1)
    }

    guard args.count >= 4 else {
        print("Error: Missing arguments for resolution set")
        print("Usage: displayctl resolution set <display> <width> <height> [refresh]")
        exit(1)
    }

    guard let displayIndex = UInt32(args[1]),
          let width = Int(args[2]),
          let height = Int(args[3]) else {
        print("Error: Invalid arguments")
        exit(1)
    }

    let refreshRate: Double? = args.count >= 5 ? Double(args[4]) : nil

    do {
        let manager = DisplayManager.shared
        try manager.setMode(displayIndex: displayIndex, width: width, height: height, refreshRate: refreshRate)

        if let refresh = refreshRate {
            print("Display \(displayIndex) resolution set to \(width)x\(height)@\(Int(refresh))Hz")
        } else {
            print("Display \(displayIndex) resolution set to \(width)x\(height)")
        }
    } catch {
        handleError(error)
    }
}

func handleConfigCommand(_ args: [String]) {
    guard args.count >= 1 else {
        print("Error: Missing config subcommand")
        print("Usage: displayctl config [list|show|save|apply|delete|init|path]")
        exit(1)
    }

    let configManager = ConfigurationManager.shared

    do {
        switch args[0] {
        case "list":
            let configs = try configManager.loadConfigurations()
            if configs.isEmpty {
                print("No saved configurations")
                print("Use 'displayctl config init' to create sample configurations")
            } else {
                print("Saved configurations:")
                for config in configs {
                    let mirrorState = config.mirroring == .enabled ? "mirrored" : "extended"
                    print("  \(config.name) (\(mirrorState), \(config.displays.count) display(s))")
                }
            }

        case "show":
            guard args.count >= 2 else {
                print("Error: Missing configuration name")
                exit(1)
            }
            guard let config = try configManager.getConfiguration(named: args[1]) else {
                print("Error: Configuration '\(args[1])' not found")
                exit(1)
            }

            print("Configuration: \(config.name)")
            print("Mirroring: \(config.mirroring.rawValue)")
            print("Displays:")
            for display in config.displays {
                if let width = display.width, let height = display.height {
                    var modeStr = "  Display \(display.index): \(width)x\(height)"
                    if let refresh = display.refreshRate {
                        modeStr += "@\(Int(refresh))Hz"
                    }
                    print(modeStr)
                }
            }

        case "save":
            guard args.count >= 2 else {
                print("Error: Missing configuration name")
                exit(1)
            }
            let config = try configManager.captureCurrentConfiguration(name: args[1])
            try configManager.saveConfiguration(config)
            print("Configuration '\(args[1])' saved")

        case "apply":
            guard args.count >= 2 else {
                print("Error: Missing configuration name")
                exit(1)
            }
            try configManager.applyConfiguration(named: args[1])
            print("Configuration '\(args[1])' applied")

        case "delete":
            guard args.count >= 2 else {
                print("Error: Missing configuration name")
                exit(1)
            }
            try configManager.deleteConfiguration(named: args[1])
            print("Configuration '\(args[1])' deleted")

        case "init":
            try configManager.createSampleConfiguration()
            print("Sample configuration file created at:")
            print(configManager.configFileURL.path)

        case "path":
            print(configManager.configFileURL.path)

        default:
            print("Error: Unknown config subcommand '\(args[0])'")
            exit(1)
        }
    } catch {
        handleError(error)
    }
}

// MARK: - Main

let args = Array(CommandLine.arguments.dropFirst())

guard !args.isEmpty else {
    printUsage()
    exit(0)
}

let command = args[0]
let commandArgs = Array(args.dropFirst())

switch command {
case "help", "-h", "--help":
    printUsage()

case "version", "-v", "--version":
    printVersion()

case "list", "ls":
    listDisplays()

case "mirror":
    handleMirrorCommand(commandArgs)

case "resolution", "res":
    handleResolutionCommand(commandArgs)

case "config":
    handleConfigCommand(commandArgs)

default:
    print("Error: Unknown command '\(command)'")
    print("Run 'displayctl help' for usage information")
    exit(1)
}
