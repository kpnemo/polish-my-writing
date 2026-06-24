import SwiftUI
import PolishCore
import struct PolishCore.Settings

@MainActor
final class AppState: ObservableObject {
    @Published var settings: Settings
    let settingsStore: SettingsStore
    let secretStore: SecretStore

    private let capturing = TextCaptureService()
    private let hotkeys = HotkeyManager()
    private var notifier: Notifier!
    private var service: PolishService!

    var openSettings: () -> Void = {}

    init(
        settingsStore: SettingsStore = SettingsStore(),
        secretStore: SecretStore = KeychainStore()
    ) {
        self.settingsStore = settingsStore
        self.secretStore = secretStore
        self.settings = settingsStore.load()

        self.notifier = Notifier(openSettings: { [weak self] in self?.openSettings() })
        self.service = PolishService(
            settingsProvider: { [weak self] in self?.settings ?? .default },
            secretStore: secretStore,
            capturing: capturing,
            notifier: notifier,
            factory: DefaultProviderFactory(),
            restoreDelayNanos: 150_000_000
        )
        registerHotkey()
    }

    func start() {
        _ = PermissionsManager.requestAccessibility()
    }

    private func registerHotkey() {
        hotkeys.register(settings.hotkey) { [weak self] in
            guard let self else { return }
            Task { await self.service.polishSelection() }
        }
    }

    func update(_ mutate: (inout Settings) -> Void) {
        var copy = settings
        mutate(&copy)
        settings = copy
        settingsStore.save(copy)
        registerHotkey() // re-register in case the hotkey changed
    }

    func apiKey(for provider: Provider) -> String {
        ((try? secretStore.apiKey(for: provider)) ?? nil) ?? ""
    }

    func setAPIKey(_ key: String, for provider: Provider) {
        try? secretStore.setAPIKey(key.isEmpty ? nil : key, for: provider)
    }
}
