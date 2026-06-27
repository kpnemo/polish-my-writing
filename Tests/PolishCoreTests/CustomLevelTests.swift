import XCTest
@testable import PolishCore

final class CustomLevelTests: XCTestCase {
    func test_customLevel_usesProvidedInstruction() {
        let prompt = PromptBuilder.systemPrompt(for: .custom, customPrompt: "Make it sound pirate-like.")
        XCTAssertTrue(prompt.contains("CUSTOM"))
        XCTAssertTrue(prompt.contains("pirate-like"))
        // Core preservation rules always present.
        XCTAssertTrue(prompt.lowercased().contains("same language"))
        XCTAssertTrue(prompt.lowercased().contains("only the polished text"))
    }

    func test_customLevel_emptyInstruction_fallsBackToStandard() {
        let empty = PromptBuilder.systemPrompt(for: .custom, customPrompt: "   \n ")
        let standard = PromptBuilder.systemPrompt(for: .standard)
        XCTAssertEqual(empty, standard)
    }

    func test_builtInLevels_ignoreCustomPrompt() {
        let withCustom = PromptBuilder.systemPrompt(for: .light, customPrompt: "ignored")
        let without = PromptBuilder.systemPrompt(for: .light)
        XCTAssertEqual(withCustom, without)
    }

    func test_settings_customPrompt_default_andTolerantDecode() throws {
        XCTAssertFalse(Settings.default.customPrompt.isEmpty)

        // Old persisted data without customPrompt keeps the default.
        let json = #"{ "provider": "openai", "level": "custom" }"#
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.level, .custom)
        XCTAssertEqual(decoded.customPrompt, Settings.defaultCustomPrompt)
    }

    func test_settings_customPrompt_roundTrips() throws {
        var s = Settings.default
        s.level = .custom
        s.customPrompt = "Be extremely concise."
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(s, back)
        XCTAssertEqual(back.customPrompt, "Be extremely concise.")
    }
}
