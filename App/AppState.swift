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
    private let settingsWindow = SettingsWindowController()
    private let accessibilityWindow = AccessibilityWindowController()
    private var notifier: Notifier!
    private var service: PolishService!
    private var isPolishing = false

    private enum HotkeyID {
        static let polish: UInt32 = 1
        static let settings: UInt32 = 2
    }

    init(
        settingsStore: SettingsStore = SettingsStore(),
        secretStore: SecretStore = KeychainStore()
    ) {
        self.settingsStore = settingsStore
        self.secretStore = secretStore
        self.settings = settingsStore.load()

        self.notifier = Notifier(openSettings: { [weak self] in self?.presentSettings() })
        self.service = PolishService(
            settingsProvider: { [weak self] in self?.settings ?? .default },
            secretStore: secretStore,
            capturing: capturing,
            notifier: notifier,
            factory: DefaultProviderFactory(),
            restoreDelayNanos: 150_000_000
        )
        registerHotkeys()
        // No launch-time Accessibility prompt: we ask only when the user actually
        // invokes the polish shortcut without permission (see registerHotkeys),
        // which avoids nagging on every launch.
    }

    /// Opens the Settings window and brings it to the front. Works on first run and
    /// when the menu-bar icon is hidden.
    func presentSettings() {
        settingsWindow.show { SettingsView(state: self) }
    }

    /// Prompts for Accessibility permission and, once granted, relaunches the app
    /// automatically so the new process is trusted and ready to polish.
    func requestAccessibility() {
        guard !PermissionsManager.hasAccessibility() else { return }
        accessibilityWindow.show(
            openSettings: {
                _ = PermissionsManager.requestAccessibility()   // lists the app in Accessibility
                PermissionsManager.openAccessibilitySettings()  // open the pane directly
            },
            restart: { Relauncher.relaunch() }
        )
    }

    private func registerHotkeys() {
        let polishOK = hotkeys.register(id: HotkeyID.polish, settings.hotkey) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                // The synthetic ⌘C/⌘V are silently dropped without Accessibility
                // trust, so guide the user instead of failing mysteriously.
                guard PermissionsManager.hasAccessibility() else {
                    self.requestAccessibility()
                    return
                }
                // Serialize fires: ignore a new hotkey press while a polish is in
                // flight, so a rapid double-tap can't corrupt the saved clipboard.
                guard !self.isPolishing else { return }
                self.isPolishing = true
                await self.service.polishSelection()
                self.isPolishing = false
            }
        }
        let settingsOK = hotkeys.register(id: HotkeyID.settings, settings.settingsHotkey) { [weak self] in
            Task { @MainActor in self?.presentSettings() }
        }
        if !polishOK {
            notifier.notify("Could not register the polish shortcut (\(settings.hotkey.displayString)) — another app may be using it. Pick a different one in Settings.")
        }
        if !settingsOK {
            notifier.notify("Could not register the settings shortcut (\(settings.settingsHotkey.displayString)) — another app may be using it. Pick a different one in Settings.")
        }
    }

    /// Temporarily disables the global shortcuts (used while the user is recording
    /// a new shortcut, so the keystroke can't also trigger a polish).
    func suspendGlobalHotkeys() {
        hotkeys.unregister(id: HotkeyID.polish)
        hotkeys.unregister(id: HotkeyID.settings)
    }

    func resumeGlobalHotkeys() {
        registerHotkeys()
    }

    func update(_ mutate: (inout Settings) -> Void) {
        var copy = settings
        mutate(&copy)
        // No-op guard: assigning an unchanged value still fires @Published
        // objectWillChange. SwiftUI writes bindings (MenuBarExtra `isInserted`, the
        // level Picker) back during its own menu/scene update; without this guard
        // those same-value writes re-dirty the graph and create an infinite update
        // loop that pins the main thread. Only proceed when something changed.
        guard copy != settings else { return }
        let hotkeysChanged = copy.hotkey != settings.hotkey
            || copy.settingsHotkey != settings.settingsHotkey
        settings = copy
        settingsStore.save(copy)
        if hotkeysChanged { registerHotkeys() } // re-register only when a shortcut changed
    }

    func apiKey(for provider: Provider) -> String {
        ((try? secretStore.apiKey(for: provider)) ?? nil) ?? ""
    }

    func setAPIKey(_ key: String, for provider: Provider) {
        try? secretStore.setAPIKey(key.isEmpty ? nil : key, for: provider)
    }
}
