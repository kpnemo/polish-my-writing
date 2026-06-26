import XCTest
import Foundation
@testable import PolishCore

final class ProviderTests: XCTestCase {
    func test_polishLevel_hasThreeCases() {
        XCTAssertEqual(PolishLevel.allCases, [.light, .standard, .thorough])
    }

    func test_provider_defaultModels() {
        XCTAssertEqual(Provider.anthropic.defaultModel, "claude-haiku-4-5-20251001")
        XCTAssertEqual(Provider.openai.defaultModel, "gpt-4o-mini")
        XCTAssertEqual(Provider.openrouter.defaultModel, "openai/gpt-4o-mini")
    }

    func test_provider_displayNames() {
        XCTAssertEqual(Provider.anthropic.displayName, "Anthropic")
        XCTAssertEqual(Provider.openai.displayName, "OpenAI")
        XCTAssertEqual(Provider.openrouter.displayName, "OpenRouter")
    }

    func test_provider_apiKeysURLs() {
        XCTAssertTrue(Provider.anthropic.apiKeysURL.contains("console.anthropic.com"))
        XCTAssertTrue(Provider.openai.apiKeysURL.contains("platform.openai.com"))
        XCTAssertTrue(Provider.openrouter.apiKeysURL.contains("openrouter.ai"))
        for p in Provider.allCases { XCTAssertNotNil(URL(string: p.apiKeysURL)) }
    }
}
