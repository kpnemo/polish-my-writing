import XCTest
import Foundation
@testable import PolishCore

final class ProviderTests: XCTestCase {
    func test_polishLevel_hasFourCases() {
        XCTAssertEqual(PolishLevel.allCases, [.light, .standard, .thorough, .custom])
    }

    func test_models_topThree_recommendedFirstMatchesDefault() {
        for p in Provider.allCases {
            XCTAssertEqual(p.models.count, 3, "\(p) should offer three picks")
            XCTAssertEqual(p.models.first?.id, p.defaultModel,
                           "\(p) recommended model must equal defaultModel")
            for m in p.models {
                XCTAssertFalse(m.id.isEmpty)
                XCTAssertFalse(m.displayName.isEmpty)
            }
            XCTAssertEqual(Set(p.models.map(\.id)).count, p.models.count)
        }
    }

    func test_provider_defaultModels() {
        XCTAssertEqual(Provider.anthropic.defaultModel, "claude-haiku-4-5-20251001")
        XCTAssertEqual(Provider.openai.defaultModel, "gpt-4o-mini")
        XCTAssertEqual(Provider.openrouter.defaultModel, "openai/gpt-4o-mini")
        XCTAssertEqual(Provider.gemini.defaultModel, "gemini-2.5-flash")
    }

    func test_provider_displayNames() {
        XCTAssertEqual(Provider.anthropic.displayName, "Anthropic")
        XCTAssertEqual(Provider.openai.displayName, "OpenAI")
        XCTAssertEqual(Provider.openrouter.displayName, "OpenRouter")
        XCTAssertEqual(Provider.gemini.displayName, "Google Gemini")
    }

    func test_provider_apiKeysURLs() {
        XCTAssertTrue(Provider.anthropic.apiKeysURL.contains("console.anthropic.com"))
        XCTAssertTrue(Provider.openai.apiKeysURL.contains("platform.openai.com"))
        XCTAssertTrue(Provider.openrouter.apiKeysURL.contains("openrouter.ai"))
        XCTAssertTrue(Provider.gemini.apiKeysURL.contains("aistudio.google.com"))
        for p in Provider.allCases { XCTAssertNotNil(URL(string: p.apiKeysURL)) }
    }
}
