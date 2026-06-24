import XCTest
@testable import PolishCore

final class SettingsStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        // Unique suite name per test run avoids cross-test pollution.
        let suite = "PolishCoreTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    func test_load_returnsDefault_whenNothingStored() {
        let store = SettingsStore(defaults: makeDefaults())
        XCTAssertEqual(store.load(), .default)
    }

    func test_save_thenLoad_roundTrips() {
        let store = SettingsStore(defaults: makeDefaults())
        var s = Settings.default
        s.provider = .openai
        s.model = "gpt-4o"
        s.level = .thorough
        store.save(s)
        XCTAssertEqual(store.load(), s)
    }

    func test_load_returnsDefault_whenStoredDataIsCorrupt() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "settings")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.load(), .default)
    }
}
