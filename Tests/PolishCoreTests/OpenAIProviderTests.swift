import XCTest
@testable import PolishCore

final class OpenAIProviderTests: XCTestCase {
    func test_buildsCorrectRequest_andParsesResponse() async throws {
        var captured: URLRequest?
        let transport: HTTPTransport = { request in
            captured = request
            let json = """
            {"choices":[{"message":{"role":"assistant","content":"Polished."}}]}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(json.utf8), response)
        }
        let provider = OpenAIProvider(apiKey: "sk-oa", transport: transport)

        let result = try await provider.polish(text: "polsh", systemPrompt: "SYS", model: "gpt-4o-mini")

        XCTAssertEqual(result, "Polished.")
        let req = try XCTUnwrap(captured)
        XCTAssertEqual(req.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-oa")

        let body = try JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(body?["model"] as? String, "gpt-4o-mini")
        let messages = body?["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.count, 2)
        XCTAssertEqual(messages?[0]["role"] as? String, "system")
        XCTAssertEqual(messages?[0]["content"] as? String, "SYS")
        XCTAssertEqual(messages?[1]["role"] as? String, "user")
        XCTAssertEqual(messages?[1]["content"] as? String, "polsh")
    }

    func test_httpError_throwsPolishError() async {
        let transport: HTTPTransport = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (Data("rate limited".utf8), response)
        }
        let provider = OpenAIProvider(apiKey: "k", transport: transport)
        do {
            _ = try await provider.polish(text: "x", systemPrompt: "S", model: "m")
            XCTFail("Expected throw")
        } catch let error as PolishError {
            guard case .http(429, _) = error else { return XCTFail("Wrong error: \(error)") }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
