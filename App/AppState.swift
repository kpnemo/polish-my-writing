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

    private enum HotkeyID {
        static let polish: UInt32 = 1
        static let settings: UInt32 = 2
    }

    /// Opens the Settings window programmatically and brings it to the front
    /// (above other apps' windows). Has a working default so it works on first run
    /// and when the menu-bar icon is hidden.
    var openSettings: () -> Void = {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        // The SwiftUI Settings window may be created asynchronously; bring it
        // forward once it exists so it never hides behind other windows.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let window = NSApp.windows.first {
                $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
            } ?? NSApp.windows.first { $0.isVisible && $0.canBecomeMain }
            window?.makeKeyAndOrderFront(nil)
            window?.orderFrontRegardless()
        }
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
        registerHotkeys()
        // Request Accessibility at launch (not lazily when Settings opens), since
        // the synthetic ⌘C/⌘V are no-ops without it — the core feature depends on it.
        start()
    }

    func start() {
        _ = PermissionsManager.requestAccessibility()
    }

    private func registerHotkeys() {
        let polishOK = hotkeys.register(id: HotkeyID.polish, settings.hotkey) { [weak self] in
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
        let settingsOK = hotkeys.register(id: HotkeyID.settings, settings.settingsHotkey) { [weak self] in
            self?.openSettings()
        }
        if !polishOK {
            notifier.notify("Could not register the polish shortcut (\(settings.hotkey.displayString)) — another app may be using it. Pick a different one in Settings.")
        }
        if !settingsOK {
            notifier.notify("Could not register the settings shortcut (\(settings.settingsHotkey.displayString)) — another app may be using it. Pick a different one in Settings.")
        }
    }

    func update(_ mutate: (inout Settings) -> Void) {
        var copy = settings
        mutate(&copy)
        settings = copy
        settingsStore.save(copy)
        registerHotkeys() // re-register in case either shortcut changed
    }

    func apiKey(for provider: Provider) -> String {
        ((try? secretStore.apiKey(for: provider)) ?? nil) ?? ""
    }

    func setAPIKey(_ key: String, for provider: Provider) {
        try? secretStore.setAPIKey(key.isEmpty ? nil : key, for: provider)
    }
}
