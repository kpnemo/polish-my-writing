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

    func test_defaultSettingsHotkey_isOptionCommandComma() {
        let h = Settings.default.settingsHotkey
        XCTAssertEqual(h.keyCode, 43) // ','
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

    func test_tolerantDecode_fillsMissingFieldsWithDefaults() throws {
        // Simulates older persisted data that predates `settingsHotkey` and omits
        // some fields entirely — decoding must succeed and backfill defaults.
        let json = """
        { "provider": "openai", "level": "thorough" }
        """
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.provider, .openai)
        XCTAssertEqual(decoded.level, .thorough)
        XCTAssertEqual(decoded.model, Settings.default.model)
        XCTAssertEqual(decoded.hotkey, .default)
        XCTAssertEqual(decoded.settingsHotkey, .defaultSettings)
        XCTAssertTrue(decoded.showMenuBarIcon)
    }

    func test_hotkeyDisplayString() {
        XCTAssertEqual(HotkeyConfig.default.displayString, "⌥⌘P")
        XCTAssertEqual(HotkeyConfig.defaultSettings.displayString, "⌥⌘,")
    }
}
