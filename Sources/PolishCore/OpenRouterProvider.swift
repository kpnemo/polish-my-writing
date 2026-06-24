import Foundation

public struct OpenRouterProvider: LLMProvider {
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
            url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!,
            apiKey: apiKey,
            extraHeaders: [
                "X-Title": "Polish My Writing",
                "HTTP-Referer": "https://polishmywriting.app",
            ],
            transport: transport
        )
    }
}
