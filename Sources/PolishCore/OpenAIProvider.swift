import Foundation

public struct OpenAIProvider: LLMProvider {
    private let apiKey: String
    private let transport: HTTPTransport

    public init(apiKey: String, transport: @escaping HTTPTransport = liveTransport) {
        self.apiKey = apiKey
        self.transport = transport
    }

    public func polish(text: String, systemPrompt: String, model: String) async throws -> String {
        try await ChatCompletions.polish(
            text: text,
            systemPrompt: systemPrompt,
            model: model,
            url: URL(string: "https://api.openai.com/v1/chat/completions")!,
            apiKey: apiKey,
            extraHeaders: [:],
            transport: transport
        )
    }
}

enum ChatCompletions {
    static func polish(
        text: String,
        systemPrompt: String,
        model: String,
        url: URL,
        apiKey: String,
        extraHeaders: [String: String],
        transport: HTTPTransport
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        for (k, v) in extraHeaders { request.setValue(v, forHTTPHeaderField: k) }

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport(request)
        } catch {
            throw PolishError.network(error.localizedDescription)
        }
        let validated = try validateHTTP(data, response)

        guard let root = try? JSONSerialization.jsonObject(with: validated) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any]
        else { throw PolishError.decoding }

        guard let content = message["content"] as? String, !content.isEmpty else {
            throw PolishError.emptyResponse
        }
        return content
    }
}
