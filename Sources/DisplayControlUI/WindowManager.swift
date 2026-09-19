// WindowManager.swift
// Native macOS window controller for the Preset Manager GUI
//
// Part of DisplayControl
// Licensed under GPL-3.0

import AppKit
import SwiftUI

@MainActor
public final class WindowManager: NSObject, NSWindowDelegate {
    public static let shared = WindowManager()

    private var windowController: NSWindowController?
    private var mainMenuConfigured = false

    private override init() {
        super.init()
    }

    /// Activates the application and brings the Preset Manager window to the foreground as a regular GUI app.
    public func showPresetManager(store: PresetStore) {
        store.load()

        // Switch activation policy to .regular so the app appears in Dock, Command-Tab, and gains main menu
        NSApp.setActivationPolicy(.regular)
        setupMainMenuIfNeeded()

        if let existing = windowController, let window = existing.window {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = PresetManagerView(store: store)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "DisplayControl Presets"
        window.setContentSize(NSSize(width: 820, height: 540))
        window.minSize = NSSize(width: 680, height: 460)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.tabbingMode = .disallowed
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        let toolbar = NSToolbar(identifier: "PresetManagerToolbar")
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar

        let wc = NSWindowController(window: window)
        self.windowController = wc
        wc.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    public func windowWillClose(_ notification: Notification) {
        // When Preset Manager window is closed, return to accessory policy so it remains in menu bar
        // without cluttering Dock or Command-Tab switcher
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Main Menu Configuration

    public func setupMainMenuIfNeeded() {
        guard !mainMenuConfigured || NSApp.mainMenu == nil else { return }

        let mainMenu = NSMenu()

        // 1. App Menu (DisplayControl)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About DisplayControl", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide DisplayControl", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit DisplayControl", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let newPresetItem = NSMenuItem(title: "New Preset...", action: #selector(handleNewPreset), keyEquivalent: "n")
        newPresetItem.target = self
        fileMenu.addItem(newPresetItem)
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 4. View Menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let toggleSidebarItem = NSMenuItem(title: "Toggle Sidebar", action: #selector(handleToggleSidebar), keyEquivalent: "s")
        toggleSidebarItem.keyEquivalentModifierMask = [.command, .control]
        toggleSidebarItem.target = self
        viewMenu.addItem(toggleSidebarItem)
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // 5. Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // 6. Help Menu
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        let helpLinkItem = NSMenuItem(title: "DisplayControl Help", action: #selector(handleOpenHelp), keyEquivalent: "?")
        helpLinkItem.target = self
        helpMenu.addItem(helpLinkItem)
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        NSApp.mainMenu = mainMenu
        mainMenuConfigured = true
    }

    @objc private func handleNewPreset() {
        NotificationCenter.default.post(name: Notification.Name("DisplayControlNewPreset"), object: nil)
    }

    @objc private func handleToggleSidebar() {
        NotificationCenter.default.post(name: Notification.Name("DisplayControlToggleSidebar"), object: nil)
    }

    @objc private func handleOpenHelp() {
        if let url = URL(string: "https://github.com/happitec-inc/displayctrl") {
            NSWorkspace.shared.open(url)
        }
    }
}
