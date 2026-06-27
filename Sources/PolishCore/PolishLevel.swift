public enum PolishLevel: String, Codable, CaseIterable, Sendable {
    case light
    case standard
    case thorough
    /// User-defined level: the polishing instruction comes from
    /// `Settings.customPrompt` instead of a built-in clause.
    case custom

    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .standard: return "Standard"
        case .thorough: return "Thorough"
        case .custom: return "Custom"
        }
    }
}
