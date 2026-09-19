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

        if let capturePath = ProcessInfo.processInfo.environment["CAPTURE_SCREENSHOT_PATH"] {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                guard let window = NSApp.windows.first(where: { $0.title.contains("DisplayControl") || $0.identifier?.rawValue == "preset-manager" }) ?? NSApp.windows.first,
                      let frameView = window.contentView?.superview else {
                    print("Window not found for screenshot")
                    return
                }
                window.appearance = NSAppearance(named: .darkAqua)
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                try? await Task.sleep(for: .milliseconds(500))

                let bounds = frameView.bounds

                // Render into bitmap rep with opaque background
                guard let rep = frameView.bitmapImageRepForCachingDisplay(in: bounds) else {
                    print("Could not create bitmapImageRep")
                    return
                }
                frameView.cacheDisplay(in: bounds, to: rep)

                // Composite over solid white/window background to eliminate transparent vibrancy black-out
                let finalImg = NSImage(size: bounds.size)
                finalImg.lockFocus()
                NSColor.windowBackgroundColor.setFill()
                bounds.fill()
                let tempImg = NSImage(size: bounds.size)
                tempImg.addRepresentation(rep)
                tempImg.draw(in: bounds)
                finalImg.unlockFocus()

                if let tiff = finalImg.tiffRepresentation,
                   let finalRep = NSBitmapImageRep(data: tiff),
                   let data = finalRep.representation(using: .png, properties: [:]) {
                    try? data.write(to: URL(fileURLWithPath: capturePath))
                    print("Saved composited screenshot to \(capturePath)")
                }
                if ProcessInfo.processInfo.environment["AUTO_QUIT_AFTER_CAPTURE"] == "1" {
                    NSApp.terminate(nil)
                }
            }
        }
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
        .defaultSize(width: 780, height: 620)
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
