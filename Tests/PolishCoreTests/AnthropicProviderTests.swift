import XCTest
@testable import PolishCore

final class AnthropicProviderTests: XCTestCase {
    func test_buildsCorrectRequest_andParsesResponse() async throws {
        var captured: URLRequest?
        let transport: HTTPTransport = { request in
            captured = request
            let json = """
            {"content":[{"type":"text","text":"Polished text."}]}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(json.utf8), response)
        }
        let provider = AnthropicProvider(apiKey: "sk-test", transport: transport)

        let result = try await provider.polish(text: "polsh this", systemPrompt: "SYS", model: "claude-haiku-4-5-20251001")

        XCTAssertEqual(result, "Polished text.")
        let req = try XCTUnwrap(captured)
        XCTAssertEqual(req.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "sk-test")
        XCTAssertEqual(req.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")

        let body = try JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(body?["model"] as? String, "claude-haiku-4-5-20251001")
        XCTAssertEqual(body?["system"] as? String, "SYS")
        let messages = body?["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.first?["role"] as? String, "user")
        XCTAssertEqual(messages?.first?["content"] as? String, "polsh this")
    }

    func test_httpError_throwsPolishError() async {
        let transport: HTTPTransport = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data("unauthorized".utf8), response)
        }
        let provider = AnthropicProvider(apiKey: "bad", transport: transport)
        do {
            _ = try await provider.polish(text: "x", systemPrompt: "S", model: "m")
            XCTFail("Expected throw")
        } catch let error as PolishError {
            guard case .http(401, _) = error else { return XCTFail("Wrong error: \(error)") }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_emptyContent_throwsEmptyResponse() async {
        let transport: HTTPTransport = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(#"{"content":[]}"#.utf8), response)
        }
        let provider = AnthropicProvider(apiKey: "k", transport: transport)
        do {
            _ = try await provider.polish(text: "x", systemPrompt: "S", model: "m")
            XCTFail("Expected throw")
        } catch let error as PolishError {
            XCTAssertEqual(error, .emptyResponse)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
