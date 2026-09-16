import XCTest
@testable import DisplayControlCore

final class DisplayControlTests: XCTestCase {
    func testDisplayConfigurationSerialization() throws {
        let config = DisplayConfiguration(
            name: "test-config",
            mirroring: .enabled,
            displays: [
                DisplayConfiguration.DisplayConfig(
                    index: 0,
                    width: 1920,
                    height: 1080,
                    refreshRate: 60.0
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DisplayConfiguration.self, from: data)

        XCTAssertEqual(decoded.name, "test-config")
        XCTAssertEqual(decoded.mirroring, .enabled)
        XCTAssertEqual(decoded.displays.count, 1)
        XCTAssertEqual(decoded.displays[0].index, 0)
        XCTAssertEqual(decoded.displays[0].width, 1920)
        XCTAssertEqual(decoded.displays[0].height, 1080)
        XCTAssertEqual(decoded.displays[0].refreshRate, 60.0)
    }

    func testDisplayModeDescription() {
        let mode = DisplayMode(
            width: 2560,
            height: 1440,
            refreshRate: 120.0,
            isUsableForDesktop: true,
            isCurrent: true
        )

        XCTAssertEqual(mode.description, "2560x1440@120Hz")
    }

    func testDisplayManagerInstance() {
        XCTAssertNotNil(DisplayManager.shared)
    }
}
