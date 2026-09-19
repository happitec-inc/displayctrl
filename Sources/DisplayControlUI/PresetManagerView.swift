// PresetManagerView.swift
// SwiftUI Preset Manager GUI for DisplayControl
//
// Part of DisplayControl
// Licensed under GPL-3.0

import SwiftUI
import DisplayControlCore

public struct PresetManagerView: View {
    public var store: PresetStore

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("displaycontrol_sidebar_state") private var storedSidebarState: String = "unset"
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var selectedPresetName: String? = nil
    @State private var showingNewPresetSheet = false
    @State private var showingDeleteAlert = false
    @State private var presetToDelete: DisplayConfiguration? = nil
    @State private var focusEditorNameOnCreate = false

    private let isExplicitVisibility: Bool

    public init(
        store: PresetStore,
        initialVisibility: NavigationSplitViewVisibility? = nil
    ) {
        self.store = store
        if let visibility = initialVisibility {
            _columnVisibility = State(initialValue: visibility)
            self.isExplicitVisibility = true
        } else {
            self.isExplicitVisibility = false
        }
    }

    private var currentSelectedPreset: DisplayConfiguration? {
        guard let name = selectedPresetName else { return nil }
        return store.presets.first(where: { $0.name == name })
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
            ToolbarSpacer(.flexible)

            ToolbarItem {
                ControlGroup {
                    if let preset = currentSelectedPreset {
                        Button(role: .destructive) {
                            presetToDelete = preset
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .help("Delete Preset")
                    }

                    Button {
                        showingNewPresetSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("New Preset (⌘N)")
                }
            }

            ToolbarSpacer(.fixed)

            ToolbarItem {
                if let preset = currentSelectedPreset {
                    let isCurrentActiveAndUnedited = store.matchesLiveSetup(preset)
                    Button {
                        store.apply(preset: preset)
                    } label: {
                        Label("Apply Preset", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCurrentActiveAndUnedited)
                    .help(isCurrentActiveAndUnedited ? "Preset is already active" : "Apply Preset")
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
        }        .onAppear {
            if selectedPresetName == nil {
                selectedPresetName = store.activePresetName ?? store.presets.first?.name
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
            } else {
                List(selection: $selectedPresetName) {
                    ForEach(store.presets, id: \.name) { preset in
                        let isSelected = preset.name == selectedPresetName
                        HStack(spacing: 10) {
                            Image(systemName: presetIcon(for: preset))
                                .foregroundStyle(isSelected ? .white : (preset.name == store.activePresetName ? Color.accentColor : Color.secondary))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(preset.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(isSelected ? .white : .primary)
                                    if preset.name == store.activePresetName {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(isSelected ? .white : Color.accentColor)
                                    }
                                }

                                Text(presetSummary(for: preset))
                                    .font(.system(size: 11))
                                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                            }
                            Spacer()
                        }
                        .tag(preset.name)
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                presetToDelete = preset
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                presetToDelete = preset
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete...", systemImage: "trash")
                            }
                        }
                    }
                    .onMove(perform: store.movePresets)
                }
                .listStyle(.sidebar)
            }
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
                autoFocusName: focusEditorNameOnCreate,
                onRename: { newName in
                    selectedPresetName = newName
                },
                onFocused: {
                    focusEditorNameOnCreate = false
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
        NewPresetSheetView(
            store: store,
            onCreated: { name in
                selectedPresetName = name
                showingNewPresetSheet = false
                focusEditorNameOnCreate = true
                onPresetCreated()
            },
            onCancel: {
                showingNewPresetSheet = false
            }
        )
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

// MARK: - New Preset Sheet View

private struct NewPresetSheetView: View {
    var store: PresetStore
    var onCreated: (String) -> Void
    var onCancel: () -> Void

    @State private var newPresetName = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
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
                            onCreated(name)
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
                    .focused($isNameFieldFocused)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
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
                        onCreated(name)
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
        .onAppear {
            isNameFieldFocused = true
        }
    }
}

// MARK: - Preset Editor View

private struct PresetEditorView: View {
    let preset: DisplayConfiguration
    var store: PresetStore
    var autoFocusName: Bool = false
    var onRename: ((String) -> Void)?
    var onFocused: (() -> Void)?

    @FocusState private var isEditorNameFocused: Bool
    @State private var editedName: String = ""
    @State private var mirroringPolicy: DisplayConfiguration.MirroringConfig = .enabled
    @State private var displayConfigs: [DisplayConfiguration.DisplayConfig] = []
    @State private var lastSavedName: String = ""
    @State private var isLoadingPreset = false
    @State private var isEditingName = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Top Action Bar
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            if isEditingName {
                                TextField("Preset Name", text: $editedName)
                                    .font(.title2.bold())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 160, maxWidth: 260)
                                    .focused($isEditorNameFocused)
                                    .onSubmit {
                                        autoSave()
                                        isEditingName = false
                                    }
                                Button {
                                    autoSave()
                                    isEditingName = false
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                                .help("Save name")
                            } else {
                                Text(editedName.isEmpty ? preset.name : editedName)
                                    .font(.title.bold())

                                Button {
                                    isEditingName = true
                                    isEditorNameFocused = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Rename preset")
                            }
                        }

                        Text("Profile ID: \(preset.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if preset.name == store.activePresetName {
                        Label("Currently Active", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.85)),
                                removal: .opacity
                            ))
                    }
                }
                .animation(.spring(duration: 0.35, bounce: 0.25), value: store.activePresetName == preset.name)

                Divider()

                // Centered Arrangement & Configuration Column
                HStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 20) {
                        // Display Arrangement Hero Selection
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Display Arrangement")
                                .font(.headline)

                            HStack(spacing: 20) {
                                HeroDisplayModeCard(
                                    title: "Extended Desktop",
                                    subtitle: "Separate displays",
                                    systemImage: "rectangle.split.2x1",
                                    isSelected: mirroringPolicy == .disabled
                                ) {
                                    guard !isLoadingPreset else { return }
                                    mirroringPolicy = .disabled
                                    autoSave()
                                }

                                HeroDisplayModeCard(
                                    title: "Mirror Displays",
                                    subtitle: "Duplicate main screen",
                                    systemImage: "rectangle.on.rectangle",
                                    isSelected: mirroringPolicy == .enabled
                                ) {
                                    guard !isLoadingPreset else { return }
                                    mirroringPolicy = .enabled
                                    autoSave()
                                }
                            }
                        }

                        // Displays Configuration
                        VStack(alignment: .leading, spacing: 14) {
                            Text(configuredDisplaysSectionTitle)
                                .font(.headline)

                            VStack(spacing: 0) {
                                if displayConfigs.isEmpty {
                                    Text("No specific display resolutions bound to this preset. Mirroring policy only.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    ForEach(Array(displayConfigs.enumerated()), id: \.offset) { index, item in
                                        if index > 0 {
                                            Divider()
                                                .padding(.horizontal, 14)
                                        }
                                        displayRow(index: index, config: item)
                                    }
                                }
                            }
                            .frame(width: 420, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .frame(width: 420, alignment: .leading)
                    Spacer()
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
            loadPreset(preset)
            if autoFocusName {
                isEditingName = true
                isEditorNameFocused = true
                onFocused?()
            }
        }
        .onChange(of: preset.name) { _, newName in
            if newName != lastSavedName {
                loadPreset(preset)
                if autoFocusName {
                    isEditingName = true
                    isEditorNameFocused = true
                    onFocused?()
                }
            }
        }
        .onChange(of: isEditorNameFocused) { _, isFocused in
            if !isFocused && isEditingName {
                autoSave()
                isEditingName = false
            }
        }
    }

    private var currentEditedPreset: DisplayConfiguration {
        DisplayConfiguration(
            name: editedName.trimmingCharacters(in: .whitespacesAndNewlines),
            mirroring: mirroringPolicy,
            displays: displayConfigs
        )
    }

    private var configuredDisplaysSectionTitle: String {
        let count = displayConfigs.count
        guard count > 0 else { return "Configure displays" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        let countWord = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
        let displayWord = count == 1 ? "display" : "displays"

        switch mirroringPolicy {
        case .enabled:
            return "Configure \(countWord) mirrored \(displayWord)"
        case .disabled:
            return "Configure \(countWord) extended \(displayWord)"
        case .unchanged:
            return "Configure \(countWord) \(displayWord)"
        }
    }

    private func loadPreset(_ p: DisplayConfiguration) {
        isLoadingPreset = true
        isEditingName = false
        lastSavedName = p.name
        editedName = p.name
        mirroringPolicy = p.mirroring
        displayConfigs = p.displays
        Task { @MainActor in
            isLoadingPreset = false
        }
    }

    private func autoSave() {
        guard !isLoadingPreset else { return }
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let toSave = DisplayConfiguration(
            name: trimmed,
            mirroring: mirroringPolicy,
            displays: displayConfigs
        )

        if store.save(preset: toSave, renamingFrom: lastSavedName) {
            let oldName = lastSavedName
            lastSavedName = trimmed
            if oldName != trimmed {
                onRename?(trimmed)
            }
        }
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
            }

            HStack(spacing: 14) {
                // Resolution Selector
                HStack(spacing: 6) {
                    Text("Resolution:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize()

                    let currentResolutionString = config.width != nil && config.height != nil
                        ? "\(config.width!)x\(config.height!)"
                        : "Native / Unchanged"

                    Picker("", selection: Binding(
                        get: { currentResolutionString },
                        set: { (newVal: String) in
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
                    .frame(width: 125)
                }

                // Refresh Rate Selector
                HStack(spacing: 6) {
                    Text("Refresh:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize()

                    Picker("", selection: Binding<Double?>(
                        get: { config.refreshRate },
                        set: { (newVal: Double?) in
                            updateDisplayConfig(at: index, refreshRate: .some(newVal))
                        }
                    )) {
                        Text("Auto / Default").tag(nil as Double?)
                        ForEach(availableRefreshRates, id: \.self) { rate in
                            Text(formatRate(rate)).tag(rate as Double?)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 125)
                }

                Spacer()
            }
        }
        .padding(14)
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
        autoSave()
    }
}

// MARK: - Hero Display Mode Card

private struct HeroDisplayModeCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.35))
                }

                Spacer(minLength: 4)

                Image(systemName: systemImage)
                    .font(.system(size: 54, weight: .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : (isHovered ? Color.primary : Color.secondary))
                    .frame(height: 60)

                Spacer(minLength: 4)

                VStack(spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }
                .multilineTextAlignment(.center)
            }
            .padding(14)
            .frame(width: 200, height: 185)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : (isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.8) : Color(NSColor.controlBackgroundColor)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : (isHovered ? Color.secondary.opacity(0.4) : Color.secondary.opacity(0.2)), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview("Preset Manager - Populated") {
    PresetManagerView(store: .preview, initialVisibility: .all)
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



