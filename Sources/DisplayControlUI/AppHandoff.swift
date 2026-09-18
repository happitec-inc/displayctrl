// AppHandoff.swift
// Handles launching and focusing between the Menu Bar companion and the GUI application
//
// Part of DisplayControl
// Licensed under GPL-3.0

import AppKit

@MainActor
public enum AppHandoff {
    public static func openPresetManager(store: PresetStore? = nil) {
        // 1. Try finding by bundle identifier
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.happitec.DisplayControlApp") {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
            return
        }

        // 2. Search adjacent directories dynamically (e.g. .build or /Applications)
        var candidateURLs: [URL] = [
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("DisplayControl.app"),
            URL(fileURLWithPath: "/Applications/DisplayControl.app")
        ]

        if let execURL = Bundle.main.executableURL {
            let buildDir = execURL.deletingLastPathComponent()
            candidateURLs.append(buildDir.appendingPathComponent("DisplayControl.app"))
            candidateURLs.append(buildDir.deletingLastPathComponent().appendingPathComponent("DisplayControl.app"))
        }

        for url in candidateURLs where FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return
        }

        // 3. Fallback: activate directly if WindowManager is available in-process
        WindowManager.shared.showPresetManager(store: store ?? PresetStore())
    }
}
