// PresetManagerView.swift
// SwiftUI Preset Manager GUI for DisplayControl
//
// Part of DisplayControl
// Licensed under GPL-3.0

import SwiftUI
import DisplayControlCore

public struct PresetManagerView: View {
    public var store: PresetStore

    @AppStorage("displaycontrol_sidebar_state") private var storedSidebarState: String = "unset"
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var isEditingPresets = false
    @State private var selectedPresetName: String? = nil
    @State private var showingNewPresetSheet = false
    @State private var newPresetName = ""
    @State private var showingDeleteAlert = false
    @State private var presetToDelete: DisplayConfiguration? = nil

    private let isExplicitVisibility: Bool

    public init(
        store: PresetStore,
        initialVisibility: NavigationSplitViewVisibility? = nil,
        initialEditing: Bool = false
    ) {
        self.store = store
        if let visibility = initialVisibility {
            _columnVisibility = State(initialValue: visibility)
            self.isExplicitVisibility = true
        } else {
            self.isExplicitVisibility = false
        }
        _isEditingPresets = State(initialValue: initialEditing)
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 720, minHeight: 480)
        .toolbar {
            if columnVisibility == .detailOnly {
                ToolbarItem(placement: .navigation) {
                    Button(action: toggleSidebar) {
                        Label("Toggle Sidebar", systemImage: "sidebar.leading")
                    }
                    .help("Toggle Sidebar (⌃⌘S)")
                }
            }
        }
        .sheet(isPresented: $showingNewPresetSheet) {
            newPresetSheet
        }
        .alert("Delete Preset", isPresented: $showingDeleteAlert, presenting: presetToDelete) { preset in
            Button("Delete", role: .destructive) {
                store.delete(preset: preset)
                if selectedPresetName == preset.name {
                    selectedPresetName = store.presets.first?.name
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { preset in
            Text("Are you sure you want to delete '\(preset.name)'? This action cannot be undone.")
        }
        .onAppear {
            if selectedPresetName == nil {
                selectedPresetName = store.presets.first?.name
            }
            setupInitialSidebarVisibility()
        }
        .onChange(of: columnVisibility) { _, newVisibility in
            if !isExplicitVisibility && (!store.presets.isEmpty || storedSidebarState != "unset") {
                storedSidebarState = (newVisibility == .detailOnly ? "closed" : "open")
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: Notification.Name("DisplayControlToggleSidebar")) {
                toggleSidebar()
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: Notification.Name("DisplayControlNewPreset")) {
                showingNewPresetSheet = true
            }
        }
    }

    private func toggleSidebar() {
        withAnimation(.spring(duration: 0.25)) {
            columnVisibility = (columnVisibility == .detailOnly ? .all : .detailOnly)
        }
    }

    private func setupInitialSidebarVisibility() {
        guard !isExplicitVisibility else { return }
        switch storedSidebarState {
        case "open":
            columnVisibility = .all
        case "closed":
            columnVisibility = .detailOnly
        default:
            // First time going into GUI: collapsed if empty, open if presets already exist
            if store.presets.isEmpty {
                columnVisibility = .detailOnly
            } else {
                columnVisibility = .all
                storedSidebarState = "open"
            }
        }
    }

    private func onPresetCreated() {
        // Automatically open sidebar after making first preset and persist
        columnVisibility = .all
        storedSidebarState = "open"
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            if store.presets.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "display.2")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No Presets Defined")
                        .font(.headline)
                    Text("Define a preset to configure your displays.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedPresetName) {
                    ForEach(store.presets, id: \.name) { preset in
                        HStack(spacing: 10) {
                            if isEditingPresets {
                                Button {
                                    presetToDelete = preset
                                    showingDeleteAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.glass)
                                .glassEffect()
                                .help("Delete \(preset.name)")
                            }

                            Image(systemName: presetIcon(for: preset))
                                .foregroundStyle(preset.name == store.activePresetName ? Color.accentColor : Color.secondary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(preset.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    if preset.name == store.activePresetName {
                                        Text("Active")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(Color.green.opacity(0.2))
                                            .foregroundStyle(Color.green)
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(presetSummary(for: preset))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            if isEditingPresets {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(preset.name)
                        .padding(.vertical, 2)
                    }
                    .onMove(perform: store.movePresets)
                }
                .listStyle(.sidebar)
            }

            Divider()

            // Sidebar Bottom Actions: Edit and Define Presets...
            HStack(spacing: 8) {
                if isEditingPresets {
                    Button {
                        isEditingPresets.toggle()
                    } label: {
                        Text("Done")
                            .font(.system(size: 12, weight: .medium))
                            .frame(minWidth: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .glassEffect()
                } else {
                    Button {
                        isEditingPresets.toggle()
                    } label: {
                        Text("Edit")
                            .font(.system(size: 12, weight: .medium))
                            .frame(minWidth: 44)
                    }
                    .buttonStyle(.glass)
                    .glassEffect()
                    .disabled(store.presets.isEmpty)
                }

                Button {
                    showingNewPresetSheet = true
                } label: {
                    Label("Define Presets...", systemImage: "display.2")
                        .font(.system(size: 12))
                }
                .buttonStyle(.glassProminent)
                .glassEffect()

                Spacer()
            }
            .padding(10)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        if let selectedName = selectedPresetName,
           let preset = store.presets.first(where: { $0.name == selectedName }) {
            PresetEditorView(
                preset: preset,
                store: store,
                onRename: { newName in
                    selectedPresetName = newName
                },
                onDelete: {
                    presetToDelete = preset
                    showingDeleteAlert = true
                }
            )
        } else {
            emptyDetailView
        }
    }

    private var emptyDetailView: some View {
        VStack(spacing: 20) {
            Image(systemName: "display.2")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("No Presets Defined")
                    .font(.title2.bold())
                Text("Get started by defining your first display preset configuration.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button {
                showingNewPresetSheet = true
            } label: {
                Label("Define Presets...", systemImage: "display.2")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .glassEffect()
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Sheets

    var newPresetSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header with matching iconography
            HStack {
                Image(systemName: "display.2")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Define Presets")
                        .font(.headline)
                    Text("Capture your active setup or create a custom profile.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Top CTA: Capture Current Displays (1-click setup)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Capture Current Displays", systemImage: "camera.fill")
                            .font(.subheadline.bold())
                        Text("Instantly save your current \(store.onlineDisplays.count) monitor layout (\(store.isMirrored ? "Mirrored" : "Extended Desktop")).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Setup \(store.presets.count + 1)"
                            : newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if store.captureCurrent(name: name) {
                            selectedPresetName = name
                            newPresetName = ""
                            showingNewPresetSheet = false
                            onPresetCreated()
                        }
                    } label: {
                        Text("Capture Now")
                    }
                    .buttonStyle(.glassProminent)
                    .glassEffect()
                }
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.12))
            .cornerRadius(8)

            Divider()

            // Custom configuration
            VStack(alignment: .leading, spacing: 6) {
                Text("Or Custom Preset Name:")
                    .font(.subheadline.bold())
                TextField("e.g. presentation, vertical-reading, gaming", text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    showingNewPresetSheet = false
                }
                .buttonStyle(.glass)
                .glassEffect()
                .keyboardShortcut(.cancelAction)

                Button("Create Blank Preset") {
                    let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }

                    let displays = store.onlineDisplays.compactMap { d -> DisplayConfiguration.DisplayConfig? in
                        guard let mode = d.currentMode else { return nil }
                        return DisplayConfiguration.DisplayConfig(
                            index: d.index,
                            serialNumber: d.serialNumber,
                            width: mode.width,
                            height: mode.height,
                            refreshRate: mode.refreshRate
                        )
                    }

                    let newConfig = DisplayConfiguration(
                        name: name,
                        mirroring: store.isMirrored ? .enabled : .disabled,
                        displays: displays
                    )

                    if store.save(preset: newConfig) {
                        selectedPresetName = name
                        newPresetName = ""
                        showingNewPresetSheet = false
                        onPresetCreated()
                    }
                }
                .buttonStyle(.glassProminent)
                .glassEffect()
                .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    // MARK: - Helpers

    private func presetIcon(for preset: DisplayConfiguration) -> String {
        switch preset.mirroring {
        case .enabled:
            return "rectangle.on.rectangle"
        case .disabled:
            return "rectangle.split.2x1"
        case .unchanged:
            return "display"
        }
    }

    private func presetSummary(for preset: DisplayConfiguration) -> String {
        let mirrorDesc: String
        switch preset.mirroring {
        case .enabled: mirrorDesc = "Mirrored"
        case .disabled: mirrorDesc = "Extended"
        case .unchanged: mirrorDesc = "Keep mirroring"
        }
        return "\(preset.displays.count) display(s) • \(mirrorDesc)"
    }
}

// MARK: - Preset Editor View

private struct PresetEditorView: View {
    let preset: DisplayConfiguration
    var store: PresetStore
    var onRename: ((String) -> Void)?
    let onDelete: () -> Void

    @State private var editedName: String = ""
    @State private var mirroringPolicy: DisplayConfiguration.MirroringConfig = .enabled
    @State private var displayConfigs: [DisplayConfiguration.DisplayConfig] = []
    @State private var isDirty = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Top Action Bar
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(preset.name)
                                .font(.title.bold())
                            if preset.name == store.activePresetName {
                                Label("Currently Active", systemImage: "checkmark.circle.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        Text("Profile ID: \(preset.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        store.apply(preset: currentEditedPreset)
                    } label: {
                        Label("Apply Preset Now", systemImage: "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .glassEffect()
                    .controlSize(.regular)
                }

                Divider()

                // Configuration Details Form
                VStack(alignment: .leading, spacing: 14) {
                    Text("Configuration Settings")
                        .font(.headline)

                    // Preset Name
                    HStack {
                        Text("Name:")
                            .frame(width: 120, alignment: .leading)
                            .foregroundStyle(.secondary)
                        TextField("Preset Name", text: $editedName)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: editedName) { isDirty = true }
                    }

                    // Mirroring Policy
                    HStack {
                        Text("Mirroring:")
                            .frame(width: 120, alignment: .leading)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $mirroringPolicy) {
                            Text("Mirrored (All displays mirror main)").tag(DisplayConfiguration.MirroringConfig.enabled)
                            Text("Extended Desktop").tag(DisplayConfiguration.MirroringConfig.disabled)
                            Text("Unchanged (Keep current mirroring)").tag(DisplayConfiguration.MirroringConfig.unchanged)
                        }
                        .labelsHidden()
                        .onChange(of: mirroringPolicy) { isDirty = true }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)

                // Displays Configuration
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Configured Displays")
                            .font(.headline)
                        Spacer()
                        Text("\(displayConfigs.count) monitor(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if displayConfigs.isEmpty {
                        Text("No specific display resolutions bound to this preset. Mirroring policy only.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(Array(displayConfigs.enumerated()), id: \.offset) { index, item in
                            displayRow(index: index, config: item)
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)

                // Save & Delete Actions
                HStack(spacing: 12) {
                    Button {
                        if store.save(preset: currentEditedPreset, renamingFrom: preset.name) {
                            isDirty = false
                            onRename?(currentEditedPreset.name)
                        }
                    } label: {
                        Text("Save Changes")
                    }
                    .buttonStyle(.glassProminent)
                    .glassEffect()
                    .disabled(!isDirty)

                    Button("Reset Changes") {
                        resetToPreset()
                    }
                    .buttonStyle(.glass)
                    .glassEffect()
                    .disabled(!isDirty)

                    Spacer()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete Preset", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.glass)
                    .glassEffect()
                }
                .padding(.top, 4)

                if let success = store.successMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(success)
                            .font(.caption)
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }

                if let error = store.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(24)
        }
        .onAppear {
            resetToPreset()
        }
        .onChange(of: preset) {
            resetToPreset()
        }
    }

    private var currentEditedPreset: DisplayConfiguration {
        DisplayConfiguration(
            name: editedName,
            mirroring: mirroringPolicy,
            displays: displayConfigs
        )
    }

    private func resetToPreset() {
        editedName = preset.name
        mirroringPolicy = preset.mirroring
        displayConfigs = preset.displays
        isDirty = false
    }

    @ViewBuilder
    private func displayRow(index: Int, config: DisplayConfiguration.DisplayConfig) -> some View {
        let liveDisplay: DisplayInfo? = {
            if let serial = config.serialNumber,
               let bySerial = store.onlineDisplays.first(where: { $0.serialNumber == serial }) {
                return bySerial
            }
            return store.onlineDisplays.first(where: { $0.index == config.index })
        }()

        let availableRefreshRates: [Double] = {
            let supported: [Double]
            if let live = liveDisplay, let w = config.width, let h = config.height {
                let matchingModes = live.availableModes.filter { $0.width == w && $0.height == h }
                let rates = Set(matchingModes.map { $0.refreshRate }).sorted()
                supported = rates.isEmpty ? [60.0, 120.0, 144.0] : rates
            } else if let live = liveDisplay {
                let rates = Set(live.availableModes.map { $0.refreshRate }).sorted()
                supported = rates.isEmpty ? [60.0, 120.0, 144.0] : rates
            } else {
                supported = [60.0, 120.0, 144.0]
            }

            var result = supported
            if let current = config.refreshRate, !result.contains(where: { abs($0 - current) < 0.05 }) {
                result.append(current)
                result.sort()
            }
            return result
        }()

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Display \(config.index)\(liveDisplay?.isMain == true ? " (Main)" : "")",
                      systemImage: "display")
                    .font(.system(size: 13, weight: .semibold))

                if let serial = config.serialNumber {
                    Text("SN: \(serial)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let live = liveDisplay?.currentMode {
                    Text("Currently: \(live.description)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                // Resolution Selector
                HStack {
                    Text("Resolution:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    let currentResolutionString = config.width != nil && config.height != nil
                        ? "\(config.width!)x\(config.height!)"
                        : "Native / Unchanged"

                    Picker("", selection: Binding(
                        get: { currentResolutionString },
                        set: { (newVal: String) in
                            isDirty = true
                            if newVal == "Native / Unchanged" {
                                updateDisplayConfig(at: index, width: nil, height: nil)
                            } else {
                                let parts = newVal.split(separator: "x")
                                if parts.count == 2,
                                   let w = Int(parts[0]),
                                   let h = Int(parts[1]) {
                                    updateDisplayConfig(at: index, width: w, height: h)
                                }
                            }
                        }
                    )) {
                        Text("Native / Unchanged").tag("Native / Unchanged")

                        if let modes = liveDisplay?.availableModes {
                            let uniqueResolutions = Array(Set(modes.map { "\($0.width)x\($0.height)" })).sorted { a, b in
                                let aW = Int(a.split(separator: "x")[0]) ?? 0
                                let bW = Int(b.split(separator: "x")[0]) ?? 0
                                return aW > bW
                            }

                            Divider()
                            ForEach(uniqueResolutions, id: \.self) { res in
                                Text(res).tag(res)
                            }
                        } else if let w = config.width, let h = config.height {
                            Text("\(w)x\(h)").tag("\(w)x\(h)")
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                // Refresh Rate Selector
                HStack {
                    Text("Refresh:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: Binding<Double?>(
                        get: { config.refreshRate },
                        set: { (newVal: Double?) in
                            isDirty = true
                            updateDisplayConfig(at: index, refreshRate: .some(newVal))
                        }
                    )) {
                        Text("Auto / Default").tag(nil as Double?)
                        ForEach(availableRefreshRates, id: \.self) { rate in
                            Text(formatRate(rate)).tag(rate as Double?)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }

    private func formatRate(_ rate: Double) -> String {
        if rate.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rate)) Hz"
        } else {
            return String(format: "%.2f Hz", rate)
        }
    }

    private func updateDisplayConfig(at index: Int, width: Int? = -1, height: Int? = -1, refreshRate: Double?? = nil) {
        guard index < displayConfigs.count else { return }
        let current = displayConfigs[index]

        let newW = (width == -1) ? current.width : width
        let newH = (height == -1) ? current.height : height
        let newRate: Double?
        if let explicitRate = refreshRate {
            newRate = explicitRate
        } else {
            newRate = current.refreshRate
        }

        displayConfigs[index] = DisplayConfiguration.DisplayConfig(
            index: current.index,
            serialNumber: current.serialNumber,
            width: newW,
            height: newH,
            refreshRate: newRate,
            mirrorMasterIndex: current.mirrorMasterIndex,
            mirrorMasterSerial: current.mirrorMasterSerial
        )
    }
}

#Preview("Preset Manager - Populated") {
    PresetManagerView(store: .preview, initialVisibility: .all)
        .frame(width: 760, height: 500)
}

#Preview("Preset Manager - Edit Mode") {
    PresetManagerView(store: .preview, initialVisibility: .all, initialEditing: true)
        .frame(width: 760, height: 500)
}

#Preview("Preset Manager - Empty (Collapsed)") {
    PresetManagerView(store: .emptyPreview, initialVisibility: .detailOnly)
        .frame(width: 760, height: 500)
}

#Preview("Define Presets - Sheet") {
    PresetManagerView(store: .preview).newPresetSheet
        .frame(width: 480)
        .padding(16)
}



