import Foundation

public struct AnthropicProvider: LLMProvider {
    private let apiKey: String
    private let transport: HTTPTransport

    public init(apiKey: String, transport: @escaping HTTPTransport = liveTransport) {
        self.apiKey = apiKey
        self.transport = transport
    }

    public func polish(text: String, systemPrompt: String, model: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [["role": "user", "content": text]],
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
        guard let content = root["content"] as? [[String: Any]] else {
            throw PolishError.decoding
        }
        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        guard !text.isEmpty else { throw PolishError.emptyResponse }
        return text
    }
}
