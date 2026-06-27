/// A selectable model for a provider: a stable API id plus a human label shown
/// in the Settings picker.
public struct ModelOption: Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

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

    /// The provider's curated top picks, recommended (== `defaultModel`) first.
    /// Shown in the Settings model picker; users can still enter any other id via
    /// the "Custom…" option. `models.first!.id` is always `defaultModel`.
    public var models: [ModelOption] {
        switch self {
        case .anthropic:
            return [
                ModelOption(id: "claude-haiku-4-5-20251001", displayName: "Claude Haiku 4.5 (fast, recommended)"),
                ModelOption(id: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6 (balanced)"),
                ModelOption(id: "claude-opus-4-8", displayName: "Claude Opus 4.8 (most capable)"),
            ]
        case .openai:
            return [
                ModelOption(id: "gpt-4o-mini", displayName: "GPT-4o mini (fast, recommended)"),
                ModelOption(id: "gpt-4o", displayName: "GPT-4o (balanced)"),
                ModelOption(id: "gpt-4.1", displayName: "GPT-4.1 (capable)"),
            ]
        case .openrouter:
            return [
                ModelOption(id: "openai/gpt-4o-mini", displayName: "OpenAI GPT-4o mini (fast, recommended)"),
                ModelOption(id: "anthropic/claude-3.5-haiku", displayName: "Anthropic Claude 3.5 Haiku"),
                ModelOption(id: "google/gemini-2.5-flash", displayName: "Google Gemini 2.5 Flash"),
            ]
        case .gemini:
            return [
                ModelOption(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash (fast, recommended)"),
                ModelOption(id: "gemini-2.5-flash-lite", displayName: "Gemini 2.5 Flash-Lite (fastest)"),
                ModelOption(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro (most capable)"),
            ]
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
