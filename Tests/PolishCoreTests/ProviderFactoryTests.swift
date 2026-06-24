import XCTest
@testable import PolishCore

final class ProviderFactoryTests: XCTestCase {
    func test_makesCorrectConcreteType() {
        let factory = DefaultProviderFactory()
        XCTAssertTrue(factory.make(.anthropic, apiKey: "k") is AnthropicProvider)
        XCTAssertTrue(factory.make(.openai, apiKey: "k") is OpenAIProvider)
        XCTAssertTrue(factory.make(.openrouter, apiKey: "k") is OpenRouterProvider)
    }
}
