// WindowManager.swift
// Native macOS window controller for the Preset Manager GUI
//
// Part of DisplayControl
// Licensed under GPL-3.0

import AppKit
import SwiftUI

@MainActor
public final class WindowManager: ObservableObject {
    public static let shared = WindowManager()

    private var windowController: NSWindowController?

    private init() {}

    /// Activates the application and brings the Preset Manager window to the foreground.
    public func showPresetManager(store: PresetStore) {
        store.load()
        NSApp.activate(ignoringOtherApps: true)

        if let existing = windowController, let window = existing.window {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let contentView = PresetManagerView(store: store)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "DisplayControl Presets"
        window.setContentSize(NSSize(width: 780, height: 520))
        window.minSize = NSSize(width: 640, height: 440)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.tabbingMode = .disallowed
        window.center()
        window.isReleasedWhenClosed = false

        let wc = NSWindowController(window: window)
        self.windowController = wc
        wc.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }
}
