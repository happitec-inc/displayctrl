// DisplayControlApp.swift
// Native macOS Preset Manager GUI Application
//
// Part of DisplayControl
// Licensed under GPL-3.0

import SwiftUI
import DisplayControlCore
import DisplayControlUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
public struct DisplayControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var store = PresetStore()

    public init() {}

    public var body: some Scene {
        Window("DisplayControl Presets", id: "preset-manager") {
            PresetManagerView(store: store)
        }
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Preset...") {
                    NotificationCenter.default.post(name: Notification.Name("DisplayControlNewPreset"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
