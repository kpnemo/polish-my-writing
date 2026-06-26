import XCTest
@testable import PolishCore

final class GeminiProviderTests: XCTestCase {
    func test_buildsCorrectRequest_andParsesResponse() async throws {
        var captured: URLRequest?
        let transport: HTTPTransport = { request in
            captured = request
            let json = """
            {
              "candidates": [
                {
                  "content": {
                    "role": "model",
                    "parts": [
                      { "text": "Please fix this sentence so it sounds good." }
                    ]
                  },
                  "finishReason": "STOP",
                  "index": 0
                }
              ],
              "usageMetadata": {
                "promptTokenCount": 28,
                "candidatesTokenCount": 9,
                "totalTokenCount": 37
              },
              "modelVersion": "gemini-2.5-flash"
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(json.utf8), response)
        }
        let provider = GeminiProvider(apiKey: "gm-key", transport: transport)

        let result = try await provider.polish(
            text: "Please to fixing this sentence so it sound good.",
            systemPrompt: "SYS",
            model: "gemini-2.5-flash"
        )

        XCTAssertEqual(result, "Please fix this sentence so it sounds good.")
        let req = try XCTUnwrap(captured)
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(
            req.url?.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
        )
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-goog-api-key"), "gm-key")
        XCTAssertEqual(req.value(forHTTPHeaderField: "content-type"), "application/json")

        let body = try JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]
        let systemInstruction = body?["system_instruction"] as? [String: Any]
        let systemParts = systemInstruction?["parts"] as? [[String: Any]]
        XCTAssertEqual(systemParts?.first?["text"] as? String, "SYS")

        let contents = body?["contents"] as? [[String: Any]]
        XCTAssertEqual(contents?.first?["role"] as? String, "user")
        let userParts = contents?.first?["parts"] as? [[String: Any]]
        XCTAssertEqual(userParts?.first?["text"] as? String, "Please to fixing this sentence so it sound good.")

        let genConfig = body?["generationConfig"] as? [String: Any]
        XCTAssertEqual(genConfig?["temperature"] as? Double, 0.2)
    }

    // A model name with a space (user-editable in Settings) must not crash the app
    // (the old force-unwrap would trap); it should be percent-encoded into the URL.
    func test_modelNameWithSpace_isPercentEncodedNotTrapped() async throws {
        var captured: URLRequest?
        let transport: HTTPTransport = { request in
            captured = request
            let json = #"{"candidates":[{"content":{"role":"model","parts":[{"text":"ok"}]},"finishReason":"STOP"}]}"#
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(json.utf8), response)
        }
        let provider = GeminiProvider(apiKey: "k", transport: transport)
        let result = try await provider.polish(text: "x", systemPrompt: "S", model: "weird model")
        XCTAssertEqual(result, "ok")
        let req = try XCTUnwrap(captured)
        XCTAssertTrue(req.url?.absoluteString.contains("weird%20model") ?? false)
    }

    func test_httpError_throwsPolishError() async {
        let transport: HTTPTransport = { request in
            let json = """
            {"error": {"code": 400, "message": "API key not valid. Please pass a valid API key.", "status": "INVALID_ARGUMENT"}}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (Data(json.utf8), response)
        }
        let provider = GeminiProvider(apiKey: "bad", transport: transport)
        do {
            _ = try await provider.polish(text: "x", systemPrompt: "S", model: "m")
            XCTFail("Expected throw")
        } catch let error as PolishError {
            guard case .http(400, _) = error else { return XCTFail("Wrong error: \(error)") }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_blockedResponse_throwsEmptyResponse() async {
        // HTTP 200, but no `candidates` because the prompt was blocked by safety.
        let transport: HTTPTransport = { request in
            let json = """
            {"promptFeedback": {"blockReason": "SAFETY", "safetyRatings": [{"category": "HARM_CATEGORY_HARASSMENT", "probability": "HIGH", "blocked": true}]}}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(json.utf8), response)
        }
        let provider = GeminiProvider(apiKey: "k", transport: transport)
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
