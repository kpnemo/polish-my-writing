public protocol LLMProviderFactory {
    func make(_ provider: Provider, apiKey: String) -> LLMProvider
}

public struct DefaultProviderFactory: LLMProviderFactory {
    private let transport: HTTPTransport

    public init(transport: @escaping HTTPTransport = liveTransport) {
        self.transport = transport
    }

    public func make(_ provider: Provider, apiKey: String) -> LLMProvider {
        switch provider {
        case .anthropic: return AnthropicProvider(apiKey: apiKey, transport: transport)
        case .openai: return OpenAIProvider(apiKey: apiKey, transport: transport)
        case .openrouter: return OpenRouterProvider(apiKey: apiKey, transport: transport)
        }
    }
}
