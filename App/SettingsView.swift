import SwiftUI
import AppKit
import PolishCore

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var apiKeyDraft: String = ""
    @State private var showAdvanced = false
    // Defaults to "complete" so the setup banner never flashes before the first
    // (off-main) status read lands.
    @State private var setup = SetupStatus(hasAPIKey: true, hasAccessibility: true)

    var body: some View {
        Form {
            // On a true first run BOTH banners show; lead with the call to action
            // (what's missing) and follow with the how-to. Once set up, only the
            // how-to remains as a permanent cheat-sheet.
            if setup.isComplete {
                howToSection
            } else {
                missingConfigSection
                howToSection
            }

            Section("Provider") {
                Picker("Provider", selection: providerBinding) {
                    ForEach(Provider.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                SecureField("API Key", text: $apiKeyDraft)
                    .onSubmit { saveKey() }
                Button("Save Key") { saveKey() }
                if let url = URL(string: state.settings.provider.apiKeysURL) {
                    Link("Get your \(state.settings.provider.displayName) API key", destination: url)
                        .font(.callout)
                }
            }

            Section("Polishing") {
                Picker("Level", selection: levelBinding) {
                    ForEach(PolishLevel.allCases, id: \.self) { l in
                        Text(l.displayName).tag(l)
                    }
                }
            }

            Section("Shortcuts") {
                HotkeyRecorderView(title: "Polish selection", hotkey: polishHotkeyBinding,
                                   onRecordingChange: setHotkeysSuspended)
                HotkeyRecorderView(title: "Open settings", hotkey: settingsHotkeyBinding,
                                   onRecordingChange: setHotkeysSuspended)
            }

            Section("General") {
                Toggle("Show menu bar icon", isOn: showIconBinding)
                if !state.settings.showMenuBarIcon {
                    Text("Icon hidden. Reopen settings any time with \(state.settings.settingsHotkey.displayString).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Launch at login", isOn: launchBinding)
                // The Accessibility action lives in the setup banner above (shown
                // whenever it's missing), so it isn't duplicated here.
            }

            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                TextField("Model", text: modelBinding)
                Button("Reset to default model") {
                    state.update { $0.model = $0.provider.defaultModel }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadState() }
        // Re-poll when the window/app comes forward so the banner doesn't go stale
        // after the user grants Accessibility in System Settings and returns.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loadState()
        }
    }

    // MARK: - Banners

    @ViewBuilder private var howToSection: some View {
        Section("How to use") {
            VStack(alignment: .leading, spacing: 8) {
                Label("Welcome to Polish My Writing", systemImage: "pencil.and.scribble")
                    .font(.headline)
                Text("It fixes grammar, spelling, and wording in any app — keeping your voice, meaning, and language.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("1.  Select text in any app.")
                    Text("2.  Press \(state.settings.hotkey.displayString) — the selected text is replaced with a polished version.")
                }
                .font(.callout)
                Text("Reopen this window anytime with \(state.settings.settingsHotkey.displayString).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder private var missingConfigSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Finish setting up Polish My Writing", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Setup incomplete")
                if setup.missingAPIKey {
                    Text("Add an API key for a provider below so the app can polish your text.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if setup.missingAccessibility {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Accessibility permission is off. Turn it on in System Settings, then restart the app.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Enable Accessibility…") { state.requestAccessibility() }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - State loading (off the main actor)

    /// Loads the draft key for the current provider and recomputes the setup
    /// banner, reading the Keychain OFF the main actor so an auth prompt (e.g. a
    /// signature mismatch) can never freeze the window mid-render.
    private func loadState() {
        let store = state.secretStore                 // captured on the main actor
        let provider = state.settings.provider
        DispatchQueue.global(qos: .userInitiated).async {
            let key = ((try? store.apiKey(for: provider)) ?? nil) ?? ""
            let hasAny = hasAnyAPIKey(in: store)
            DispatchQueue.main.async {
                apiKeyDraft = key
                setup = SetupStatus(hasAPIKey: hasAny,
                                    hasAccessibility: PermissionsManager.hasAccessibility())
            }
        }
    }

    /// Loads just the draft key for a provider (used when switching providers).
    private func loadKey(for provider: Provider) {
        let store = state.secretStore
        DispatchQueue.global(qos: .userInitiated).async {
            let key = ((try? store.apiKey(for: provider)) ?? nil) ?? ""
            DispatchQueue.main.async { apiKeyDraft = key }
        }
    }

    private func saveKey() {
        state.setAPIKey(apiKeyDraft, for: state.settings.provider)
        loadState()
    }

    private func setHotkeysSuspended(_ suspended: Bool) {
        if suspended { state.suspendGlobalHotkeys() } else { state.resumeGlobalHotkeys() }
    }

    // MARK: - Bindings

    private var providerBinding: Binding<Provider> {
        Binding(
            get: { state.settings.provider },
            set: { newProvider in
                state.update {
                    $0.provider = newProvider
                    $0.model = newProvider.defaultModel
                }
                loadKey(for: newProvider)
            }
        )
    }

    private var levelBinding: Binding<PolishLevel> {
        Binding(get: { state.settings.level }, set: { v in state.update { $0.level = v } })
    }

    private var modelBinding: Binding<String> {
        Binding(get: { state.settings.model }, set: { v in state.update { $0.model = v } })
    }

    private var polishHotkeyBinding: Binding<HotkeyConfig> {
        Binding(get: { state.settings.hotkey }, set: { v in state.update { $0.hotkey = v } })
    }

    private var settingsHotkeyBinding: Binding<HotkeyConfig> {
        Binding(get: { state.settings.settingsHotkey }, set: { v in state.update { $0.settingsHotkey = v } })
    }

    private var showIconBinding: Binding<Bool> {
        Binding(get: { state.settings.showMenuBarIcon }, set: { v in state.update { $0.showMenuBarIcon = v } })
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { state.settings.launchAtLogin },
            set: { v in
                state.update { $0.launchAtLogin = v }
                LaunchAtLogin.setEnabled(v)
            }
        )
    }
}
