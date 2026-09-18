// DisplayControlApp.swift
// Main SwiftUI App with native MenuBarExtra switcher and Preset Manager GUI
//
// Part of DisplayControl
// Licensed under GPL-3.0

import SwiftUI
import DisplayControlCore
import DisplayControlUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
public struct DisplayControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = PresetStore()

    public init() {}

    public var body: some Scene {
        MenuBarExtra("DisplayControl", systemImage: store.menuBarIconName) {
            MenuBarContentView(store: store)
        }
        .menuBarExtraStyle(.menu)
    }
}
