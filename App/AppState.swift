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
    private var didRunLaunchGate = false
    private var launchObserver: NSObjectProtocol?

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

        // Launch setup gate: if the app isn't ready to use yet (no API key, or
        // Accessibility off), auto-open Settings. The preferred trigger is the
        // didFinishLaunching notification — running after the app has finished
        // launching is what makes window activation stick (otherwise the window
        // opens behind the previously frontmost app, a MenuBarExtra/LSUIElement
        // quirk). The deferred Task is a fallback in case that notification was
        // already posted before this observer registered; the re-assertion timers
        // in the window controller cover activation either way. runLaunchGateOnce()
        // makes it run exactly once. assumeIsolated is safe because the observer
        // uses queue: .main (didFinishLaunching always posts on the main thread).
        launchObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.runLaunchGateOnce() }
        }
        Task { @MainActor [weak self] in self?.runLaunchGateOnce() }
    }

    /// Runs the launch setup gate exactly once, no matter which launch trigger
    /// fires first.
    func runLaunchGateOnce() {
        guard !didRunLaunchGate else { return }
        didRunLaunchGate = true
        if let launchObserver {
            NotificationCenter.default.removeObserver(launchObserver)
            self.launchObserver = nil
        }
        presentSetupIfNeeded()
    }

    /// Opens the Settings window and brings it to the front. Works on first run and
    /// when the menu-bar icon is hidden.
    func presentSettings() {
        settingsWindow.show { SettingsView(state: self) }
    }

    /// On launch, open Settings if anything still needs setting up — an API key
    /// for any provider, or Accessibility permission. Settings carries both the
    /// "how to use" and "what's missing" banners, so every incomplete state lands
    /// there. Re-runs every launch until both requirements are satisfied; once
    /// complete it presents nothing and never interrupts.
    ///
    /// Crucially, this NEVER blocks the main thread on a Keychain read.
    /// `AXIsProcessTrusted` is cheap and main-safe, so a missing-Accessibility
    /// state opens Settings immediately. Only when Accessibility is already
    /// granted do we need the API-key answer, and that Keychain read runs OFF the
    /// main actor — if it ever triggers an auth prompt (e.g. a signature
    /// mismatch), it can't freeze launch or hide the window.
    func presentSetupIfNeeded() {
        if !PermissionsManager.hasAccessibility() {
            presentSettings()
            return
        }
        let store = secretStore
        DispatchQueue.global(qos: .userInitiated).async {
            let hasKey = hasAnyAPIKey(in: store)
            DispatchQueue.main.async { [weak self] in
                if !hasKey { self?.presentSettings() }
            }
        }
    }

    /// Shows the guided onboarding window (Open-Settings + Restart steps) when
    /// Accessibility is missing. In-process auto-detection of the grant is
    /// unreliable on macOS, so the user restarts explicitly via the window.
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
