import XCTest
@testable import PolishCore

final class OpenRouterProviderTests: XCTestCase {
    func test_usesOpenRouterEndpoint_andParsesResponse() async throws {
        var captured: URLRequest?
        let transport: HTTPTransport = { request in
            captured = request
            let json = """
            {"choices":[{"message":{"content":"OR polished."}}]}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(json.utf8), response)
        }
        let provider = OpenRouterProvider(apiKey: "sk-or", transport: transport)

        let result = try await provider.polish(text: "polsh", systemPrompt: "SYS", model: "openai/gpt-4o-mini")

        XCTAssertEqual(result, "OR polished.")
        let req = try XCTUnwrap(captured)
        XCTAssertEqual(req.url?.absoluteString, "https://openrouter.ai/api/v1/chat/completions")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-or")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Title"), "Polish My Writing")
    }
}
