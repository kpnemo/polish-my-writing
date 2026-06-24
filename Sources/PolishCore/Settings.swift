public struct Settings: Codable, Equatable, Sendable {
    public var provider: Provider
    public var model: String
    public var level: PolishLevel
    public var hotkey: HotkeyConfig
    public var showMenuBarIcon: Bool
    public var launchAtLogin: Bool

    public init(
        provider: Provider,
        model: String,
        level: PolishLevel,
        hotkey: HotkeyConfig,
        showMenuBarIcon: Bool,
        launchAtLogin: Bool
    ) {
        self.provider = provider
        self.model = model
        self.level = level
        self.hotkey = hotkey
        self.showMenuBarIcon = showMenuBarIcon
        self.launchAtLogin = launchAtLogin
    }

    public static let `default` = Settings(
        provider: .anthropic,
        model: Provider.anthropic.defaultModel,
        level: .standard,
        hotkey: .default,
        showMenuBarIcon: true,
        launchAtLogin: false
    )
}
