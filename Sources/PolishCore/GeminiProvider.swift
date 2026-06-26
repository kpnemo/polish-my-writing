import Foundation

public struct GeminiProvider: LLMProvider {
    private let apiKey: String
    private let transport: HTTPTransport

    public init(apiKey: String, transport: @escaping HTTPTransport = liveTransport) {
        self.apiKey = apiKey
        self.transport = transport
    }

    public func polish(text: String, systemPrompt: String, model: String) async throws -> String {
        // `model` is user-editable in Settings, so percent-encode it and fail
        // gracefully rather than force-unwrapping (a model name with a space would
        // otherwise make URL(string:) return nil and trap).
        guard let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent")
        else { throw PolishError.network("Invalid Gemini model name: \(model)") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let payload: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]],
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": text]],
                ],
            ],
            "generationConfig": [
                "temperature": 0.2,
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await transport(request)
        } catch {
            throw PolishError.network(error.localizedDescription)
        }
        let validated = try validateHTTP(data, response)

        guard let root = try? JSONSerialization.jsonObject(with: validated) as? [String: Any] else {
            throw PolishError.decoding
        }
        // When the prompt is blocked, `candidates` is absent/empty and `promptFeedback.blockReason`
        // is set. Likewise a non-STOP finishReason can omit `content.parts`. Treat all of these as
        // an empty response rather than a decoding failure.
        guard let candidates = root["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]]
        else { throw PolishError.emptyResponse }

        let text = parts
            .compactMap { $0["text"] as? String }
            .joined()
        guard !text.isEmpty else { throw PolishError.emptyResponse }
        return text
    }
}
