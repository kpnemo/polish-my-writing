public enum Provider: String, Codable, CaseIterable, Sendable {
    case anthropic
    case openai
    case openrouter
    case gemini

    public var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .openrouter: return "OpenRouter"
        case .gemini: return "Google Gemini"
        }
    }

    public var defaultModel: String {
        switch self {
        case .anthropic: return "claude-haiku-4-5-20251001"
        case .openai: return "gpt-4o-mini"
        case .openrouter: return "openai/gpt-4o-mini"
        case .gemini: return "gemini-2.5-flash"
        }
    }

    public var apiKeysURL: String {
        switch self {
        case .anthropic: return "https://console.anthropic.com/settings/keys"
        case .openai: return "https://platform.openai.com/api-keys"
        case .openrouter: return "https://openrouter.ai/keys"
        case .gemini: return "https://aistudio.google.com/apikey"
        }
    }
}
