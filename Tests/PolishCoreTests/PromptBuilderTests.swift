import XCTest
@testable import PolishCore

final class PromptBuilderTests: XCTestCase {
    func test_allLevels_includeCorePreservationRules() {
        for level in PolishLevel.allCases {
            let prompt = PromptBuilder.systemPrompt(for: level).lowercased()
            XCTAssertTrue(prompt.contains("same language"), "\(level) must preserve language")
            XCTAssertTrue(prompt.contains("voice"), "\(level) must preserve voice")
            XCTAssertTrue(prompt.contains("only the polished text"), "\(level) must require output-only")
            XCTAssertTrue(prompt.contains("do not"), "\(level) must forbid commentary")
        }
    }

    func test_levelSpecificClauses() {
        let light = PromptBuilder.systemPrompt(for: .light).lowercased()
        XCTAssertTrue(light.contains("spelling"))
        XCTAssertFalse(light.contains("clarity and flow"))

        let standard = PromptBuilder.systemPrompt(for: .standard).lowercased()
        XCTAssertTrue(standard.contains("grammar"))
        XCTAssertFalse(standard.contains("clarity and flow"))

        let thorough = PromptBuilder.systemPrompt(for: .thorough).lowercased()
        XCTAssertTrue(thorough.contains("clarity and flow"))
    }
}
