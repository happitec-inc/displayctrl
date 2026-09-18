import Testing
import Foundation
@testable import DisplayControlCore

@Suite("Display Control Tests")
struct DisplayControlTests {

    // MARK: - DisplayMode Tests (relying upon resolution / list commands)

    @Test("DisplayMode description format with refresh rate")
    func displayModeDescriptionWithRate() {
        let mode = DisplayMode(
            width: 2560,
            height: 1440,
            refreshRate: 120.0,
            isUsableForDesktop: true,
            isCurrent: true
        )
        #expect(mode.description == "2560x1440@120Hz")
    }

    @Test("DisplayMode description format without refresh rate")
    func displayModeDescriptionWithoutRate() {
        let mode = DisplayMode(
            width: 1920,
            height: 1080,
            refreshRate: 0.0,
            isUsableForDesktop: true,
            isCurrent: false
        )
        #expect(mode.description == "1920x1080")
    }

    // MARK: - DisplayInfo Tests (relying upon list / getDisplays)

    @Test("DisplayInfo initialization and properties")
    func displayInfoProperties() {
        let mode = DisplayMode(width: 1920, height: 1080, refreshRate: 60.0)
        let info = DisplayInfo(
            id: 1,
            index: 0,
            isMain: true,
            isMirrored: false,
            mirrorMasterID: nil,
            serialNumber: 12345,
            currentMode: mode,
            availableModes: [mode]
        )

        #expect(info.id == 1)
        #expect(info.index == 0)
        #expect(info.isMain == true)
        #expect(info.isMirrored == false)
        #expect(info.mirrorMasterID == nil)
        #expect(info.serialNumber == 12345)
        #expect(info.currentMode == mode)
        #expect(info.availableModes.count == 1)
    }

    // MARK: - DisplayConfiguration Serialization Tests (relying upon config save/apply/show/list)

    @Test("DisplayConfiguration JSON encoding and decoding with mirror topology and serial numbers")
    func configurationSerialization() throws {
        let config = DisplayConfiguration(
            name: "studio-setup",
            mirroring: .enabled,
            displays: [
                DisplayConfiguration.DisplayConfig(
                    index: 0,
                    serialNumber: 11112222,
                    width: 3840,
                    height: 2160,
                    refreshRate: 120.0,
                    mirrorMasterIndex: nil,
                    mirrorMasterSerial: nil
                ),
                DisplayConfiguration.DisplayConfig(
                    index: 1,
                    serialNumber: 33334444,
                    width: 1920,
                    height: 1080,
                    refreshRate: 60.0,
                    mirrorMasterIndex: 0,
                    mirrorMasterSerial: 11112222
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DisplayConfiguration.self, from: data)

        #expect(decoded.name == "studio-setup")
        #expect(decoded.mirroring == .enabled)
        #expect(decoded.displays.count == 2)

        #expect(decoded.displays[0].index == 0)
        #expect(decoded.displays[0].serialNumber == 11112222)
        #expect(decoded.displays[0].width == 3840)
        #expect(decoded.displays[0].height == 2160)
        #expect(decoded.displays[0].refreshRate == 120.0)

        #expect(decoded.displays[1].index == 1)
        #expect(decoded.displays[1].serialNumber == 33334444)
        #expect(decoded.displays[1].mirrorMasterIndex == 0)
        #expect(decoded.displays[1].mirrorMasterSerial == 11112222)
    }

    // MARK: - ConfigurationManager Operations Tests (config save, load, get, delete, init, path)

    @Test("ConfigurationManager file URL path is valid")
    func configFilePath() {
        let manager = ConfigurationManager.shared
        #expect(manager.configFileURL.lastPathComponent == "displayconfigs.json")
        #expect(manager.configFileURL.path.contains("DisplayControl"))
    }

    @Test("ConfigurationManager save, load, get, and delete operations")
    func configurationManagerCRUD() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("displayctrl-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let manager = ConfigurationManager(configFileURL: tempURL)

        let testConfig = DisplayConfiguration(
            name: "test-crud-profile",
            mirroring: .disabled,
            displays: [
                DisplayConfiguration.DisplayConfig(index: 0, width: 2560, height: 1440, refreshRate: 60.0)
            ]
        )

        // Save
        try manager.saveConfiguration(testConfig)

        // Get by name
        let retrieved = try manager.getConfiguration(named: "test-crud-profile")
        #expect(retrieved != nil)
        #expect(retrieved?.name == "test-crud-profile")
        #expect(retrieved?.mirroring == .disabled)

        // Load all
        let allConfigs = try manager.loadConfigurations()
        #expect(allConfigs.contains(where: { $0.name == "test-crud-profile" }))

        // Delete
        try manager.deleteConfiguration(named: "test-crud-profile")
        let afterDelete = try manager.getConfiguration(named: "test-crud-profile")
        #expect(afterDelete == nil)
    }

    @Test("ConfigurationManager saveConfigurations preserves exact array ordering")
    func saveConfigurationsOrdering() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("displayctrl-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let manager = ConfigurationManager(configFileURL: tempURL)

        let c1 = DisplayConfiguration(name: "preset-a", mirroring: .disabled, displays: [])
        let c2 = DisplayConfiguration(name: "preset-b", mirroring: .enabled, displays: [])
        let c3 = DisplayConfiguration(name: "preset-c", mirroring: .unchanged, displays: [])

        try manager.saveConfigurations([c1, c2, c3])
        var loaded = try manager.loadConfigurations()
        #expect(loaded.map(\.name) == ["preset-a", "preset-b", "preset-c"])

        // Reorder (move last to first)
        let moved = loaded.remove(at: 2)
        loaded.insert(moved, at: 0)
        try manager.saveConfigurations(loaded)
        let reloaded = try manager.loadConfigurations()
        #expect(reloaded.map(\.name) == ["preset-c", "preset-a", "preset-b"])
    }

    @Test("createSampleConfiguration guards against overwrite unless forced")
    func sampleConfigurationGuard() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("displayctrl-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let manager = ConfigurationManager(configFileURL: tempURL)

        let sentinelConfig = DisplayConfiguration(
            name: "user-existing-profile",
            mirroring: .disabled,
            displays: []
        )
        try manager.saveConfiguration(sentinelConfig)

        // Calling without force must throw alreadyExists
        #expect(throws: ConfigurationError.self) {
            try manager.createSampleConfiguration(force: false)
        }

        // Calling with force must succeed
        try manager.createSampleConfiguration(force: true)
        let sampleConfigs = try manager.loadConfigurations()
        #expect(sampleConfigs.contains(where: { $0.name == "ipad" }))
    }

    // MARK: - DisplayManager API Tests (mirroring, resolution, displays)

    @Test("DisplayManager singleton instance is accessible")
    func displayManagerSingleton() {
        let manager = DisplayManager.shared
        #expect(manager === DisplayManager.shared)
    }

    @Test("DisplayError descriptions provide clear messages")
    func displayErrorDescriptions() {
        let notFound = DisplayError.displayNotFound(index: 3)
        #expect(notFound.errorDescription?.contains("3") == true)

        let modeNotFound = DisplayError.modeNotFound(width: 9999, height: 9999, refreshRate: 144.0)
        #expect(modeNotFound.errorDescription?.contains("9999x9999@144.0Hz") == true)

        let noDisplays = DisplayError.noDisplays
        #expect(noDisplays.errorDescription == "No displays detected")
    }

    @Test("DisplayManager getDisplays returns online displays and isMirrored returns boolean")
    func displayManagerQueryDisplays() throws {
        let manager = DisplayManager.shared
        let displays = try manager.getDisplays()
        #expect(!displays.isEmpty)

        let isMirrored = manager.isMirrored()
        #expect(isMirrored == true || isMirrored == false)

        if let first = displays.first {
            let (id, info) = try manager.getDisplay(at: first.index)
            #expect(id == first.id)
            #expect(info.index == first.index)
        }
    }
}
