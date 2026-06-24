public struct Settings: Codable, Equatable, Sendable {
    public var provider: Provider
    public var model: String
    public var level: PolishLevel
    /// Global shortcut that polishes the current selection.
    public var hotkey: HotkeyConfig
    /// Global shortcut that opens the Settings window (the escape hatch when the
    /// menu-bar icon is hidden).
    public var settingsHotkey: HotkeyConfig
    public var showMenuBarIcon: Bool
    public var launchAtLogin: Bool

    public init(
        provider: Provider,
        model: String,
        level: PolishLevel,
        hotkey: HotkeyConfig,
        settingsHotkey: HotkeyConfig = .defaultSettings,
        showMenuBarIcon: Bool,
        launchAtLogin: Bool
    ) {
        self.provider = provider
        self.model = model
        self.level = level
        self.hotkey = hotkey
        self.settingsHotkey = settingsHotkey
        self.showMenuBarIcon = showMenuBarIcon
        self.launchAtLogin = launchAtLogin
    }

    public static let `default` = Settings(
        provider: .anthropic,
        model: Provider.anthropic.defaultModel,
        level: .standard,
        hotkey: .default,
        settingsHotkey: .defaultSettings,
        showMenuBarIcon: true,
        launchAtLogin: false
    )

    private enum CodingKeys: String, CodingKey {
        case provider, model, level, hotkey, settingsHotkey, showMenuBarIcon, launchAtLogin
    }

    // Tolerant decoding: any field missing from older persisted data falls back to
    // its default, so adding new settings never wipes the user's saved preferences.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings.default
        provider = try c.decodeIfPresent(Provider.self, forKey: .provider) ?? d.provider
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? d.model
        level = try c.decodeIfPresent(PolishLevel.self, forKey: .level) ?? d.level
        hotkey = try c.decodeIfPresent(HotkeyConfig.self, forKey: .hotkey) ?? d.hotkey
        settingsHotkey = try c.decodeIfPresent(HotkeyConfig.self, forKey: .settingsHotkey) ?? d.settingsHotkey
        showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? d.showMenuBarIcon
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
    }
}
