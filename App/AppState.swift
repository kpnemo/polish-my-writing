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
    private var isPolishing = false

    /// Opens the Settings window programmatically. Has a working default so the
    /// "no API key → open Settings" path works on first run, before the user has
    /// ever opened Settings themselves.
    var openSettings: () -> Void = {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

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
        // Request Accessibility at launch (not lazily when Settings opens), since
        // the synthetic ⌘C/⌘V are no-ops without it — the core feature depends on it.
        start()
    }

    func start() {
        _ = PermissionsManager.requestAccessibility()
    }

    private func registerHotkey() {
        let ok = hotkeys.register(settings.hotkey) { [weak self] in
            guard let self else { return }
            // Serialize fires: ignore a new hotkey press while a polish is in flight,
            // so a rapid double-tap can't corrupt the saved-clipboard state.
            Task { @MainActor in
                guard !self.isPolishing else { return }
                self.isPolishing = true
                await self.service.polishSelection()
                self.isPolishing = false
            }
        }
        if !ok {
            notifier.notify("Could not register the hotkey — another app may already be using it. Choose a different shortcut in Settings.")
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
