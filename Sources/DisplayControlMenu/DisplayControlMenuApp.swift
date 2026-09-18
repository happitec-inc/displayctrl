// DisplayControlMenuApp.swift
// Native macOS Menu Bar Extra Companion for DisplayControl
//
// Part of DisplayControl
// Licensed under GPL-3.0

import SwiftUI
import DisplayControlCore
import DisplayControlUI

final class MenuAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
public struct DisplayControlMenuApp: App {
    @NSApplicationDelegateAdaptor(MenuAppDelegate.self) var appDelegate
    @StateObject private var store = PresetStore()

    public init() {}

    public var body: some Scene {
        MenuBarExtra("DisplayControl", systemImage: store.menuBarIconName) {
            MenuBarPopupView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
