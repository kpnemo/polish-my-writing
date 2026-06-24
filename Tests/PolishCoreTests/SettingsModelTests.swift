import XCTest
@testable import PolishCore

final class SettingsModelTests: XCTestCase {
    func test_defaults() {
        let s = Settings.default
        XCTAssertEqual(s.provider, .anthropic)
        XCTAssertEqual(s.model, Provider.anthropic.defaultModel)
        XCTAssertEqual(s.level, .standard)
        XCTAssertTrue(s.showMenuBarIcon)
        XCTAssertFalse(s.launchAtLogin)
    }

    func test_defaultHotkey_isOptionCommandP() {
        let h = Settings.default.hotkey
        XCTAssertEqual(h.keyCode, 35) // 'P'
        XCTAssertTrue(h.command)
        XCTAssertTrue(h.option)
        XCTAssertFalse(h.shift)
        XCTAssertFalse(h.control)
    }

    func test_codableRoundTrip() throws {
        let s = Settings.default
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(s, decoded)
    }
}
