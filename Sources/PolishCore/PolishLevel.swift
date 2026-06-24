public enum PolishLevel: String, Codable, CaseIterable, Sendable {
    case light
    case standard
    case thorough

    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .standard: return "Standard"
        case .thorough: return "Thorough"
        }
    }
}
