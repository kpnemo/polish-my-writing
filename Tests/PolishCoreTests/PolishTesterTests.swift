import XCTest
@testable import PolishCore

private struct StubProvider: LLMProvider {
    let result: Result<String, PolishError>
    func polish(text: String, systemPrompt: String, model: String) async throws -> String {
        try result.get()
    }
}

private struct StubFactory: LLMProviderFactory {
    let provider: LLMProvider
    func make(_ provider: Provider, apiKey: String) -> LLMProvider { self.provider }
}

final class PolishTesterTests: XCTestCase {
    private func tester(_ result: Result<String, PolishError>) -> PolishTester {
        PolishTester(factory: StubFactory(provider: StubProvider(result: result)))
    }

    func test_success_returnsPolishedText() async {
        let r = await tester(.success("Hello, I have received your message."))
            .test(provider: .anthropic, apiKey: "sk-key", model: "m")
        XCTAssertEqual(r, .success(polished: "Hello, I have received your message."))
    }

    func test_emptyKey_failsWithoutCallingProvider() async {
        let r = await tester(.success("x")).test(provider: .anthropic, apiKey: "   ", model: "m")
        guard case .failure = r else { return XCTFail("expected failure") }
    }

    func test_emptyModel_fails() async {
        let r = await tester(.success("x")).test(provider: .anthropic, apiKey: "sk", model: " ")
        guard case .failure = r else { return XCTFail("expected failure") }
    }

    func test_httpError_surfacesUserMessage() async {
        let r = await tester(.failure(.http(status: 401, message: "invalid key")))
            .test(provider: .openai, apiKey: "bad", model: "m")
        XCTAssertEqual(r, .failure(message: PolishError.http(status: 401, message: "invalid key").userMessage))
    }

    func test_emptyResponse_isFailure() async {
        let r = await tester(.success("   ")).test(provider: .gemini, apiKey: "sk", model: "m")
        XCTAssertEqual(r, .failure(message: PolishError.emptyResponse.userMessage))
    }
}
