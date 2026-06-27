import SwiftUI
import AppKit
import PolishCore

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var apiKeyDraft: String = ""
    // Picker selection for the model: a real model id, or `customModelTag` when
    // the user wants to type an arbitrary id.
    @State private var modelTag: String = ""
    @State private var testStatus: TestStatus = .idle
    // Defaults to "complete" so the setup banner never flashes before the first
    // (off-main) status read lands.
    @State private var setup = SetupStatus(hasAPIKey: true, hasAccessibility: true)

    private let customModelTag = "__custom__"

    private enum TestStatus: Equatable {
        case idle, running
        case success(String)
        case failure(String)
    }

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
                    .onChange(of: apiKeyDraft) { testStatus = .idle }
                HStack {
                    Button("Save Key") { saveKey() }
                    Button("Test") { runTest() }
                        .disabled(apiKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty
                                  || testStatus == .running)
                }
                testResultView
                if let url = URL(string: state.settings.provider.apiKeysURL) {
                    Link("Get your \(state.settings.provider.displayName) API key", destination: url)
                        .font(.callout)
                }

                // Model lives here (not under Advanced): the recommended pick is
                // preselected; "Custom…" reveals a free-text id field.
                Picker("Model", selection: modelPickerBinding) {
                    ForEach(state.settings.provider.models) { m in
                        Text(m.displayName).tag(m.id)
                    }
                    Text("Custom…").tag(customModelTag)
                }
                if modelTag == customModelTag {
                    TextField("Model ID", text: customModelBinding)
                        .textFieldStyle(.roundedBorder)
                    Text("Any \(state.settings.provider.displayName) model id, e.g. “\(state.settings.provider.defaultModel)”.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Polishing") {
                Picker("Level", selection: levelBinding) {
                    ForEach(PolishLevel.allCases, id: \.self) { l in
                        Text(l.displayName).tag(l)
                    }
                }
                if state.settings.level == .custom {
                    Text("Your own instruction, applied on top of the rules that preserve language, meaning, and voice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Custom instruction", text: customPromptBinding, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
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
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadState() }
        // Re-poll when the window/app comes forward so the banner doesn't go stale
        // after the user grants Accessibility in System Settings and returns.
        // Refreshes ONLY the banner — never the API-key draft — so a not-yet-saved
        // key isn't wiped when the user alt-tabs out to copy it and comes back.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshSetup()
        }
    }

    // MARK: - Test result

    @ViewBuilder private var testResultView: some View {
        switch testStatus {
        case .idle:
            EmptyView()
        case .running:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Testing…").font(.caption).foregroundStyle(.secondary)
            }
        case .success(let polished):
            VStack(alignment: .leading, spacing: 2) {
                Label("It works — polished sample:", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
                Text(polished)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .failure(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.caption).foregroundStyle(.red)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func runTest() {
        testStatus = .running
        let key = apiKeyDraft
        let provider = state.settings.provider
        let model = state.settings.model
        Task { @MainActor in
            let result = await state.testKey(key, provider: provider, model: model)
            switch result {
            case .success(let polished):
                // A key that just worked is worth keeping — persist it so the
                // green "It works" can't be followed by a polish that fails for
                // lack of a saved key.
                state.setAPIKey(key, for: provider)
                refreshSetup()
                testStatus = .success(polished)
            case .failure(let message):
                testStatus = .failure(message)
            }
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
        syncModelTag()
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

    /// Recomputes only the setup banner (off-main Keychain read). Unlike
    /// `loadState()` it never touches `apiKeyDraft`, so it's safe to call on every
    /// app re-activation without clobbering an in-progress edit.
    private func refreshSetup() {
        let store = state.secretStore
        DispatchQueue.global(qos: .userInitiated).async {
            let hasAny = hasAnyAPIKey(in: store)
            DispatchQueue.main.async {
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

    /// Picks the model row that matches the saved model id, falling back to the
    /// Custom field when it isn't one of the curated picks.
    private func syncModelTag() {
        let ids = state.settings.provider.models.map(\.id)
        modelTag = ids.contains(state.settings.model) ? state.settings.model : customModelTag
    }

    private func saveKey() {
        state.setAPIKey(apiKeyDraft, for: state.settings.provider)
        testStatus = .idle
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
                testStatus = .idle
                syncModelTag()
                loadKey(for: newProvider)
            }
        )
    }

    private var levelBinding: Binding<PolishLevel> {
        Binding(get: { state.settings.level }, set: { v in state.update { $0.level = v } })
    }

    /// Drives the model Picker. Selecting a curated id saves it; selecting
    /// "Custom…" only flips the UI to the text field (the saved id is untouched
    /// until the user types).
    private var modelPickerBinding: Binding<String> {
        Binding(
            get: { modelTag },
            set: { newTag in
                modelTag = newTag
                testStatus = .idle
                if newTag != customModelTag {
                    state.update { $0.model = newTag }
                }
            }
        )
    }

    private var customModelBinding: Binding<String> {
        Binding(
            get: { state.settings.model },
            set: { v in
                state.update { $0.model = v }
                testStatus = .idle
            }
        )
    }

    private var customPromptBinding: Binding<String> {
        Binding(get: { state.settings.customPrompt },
                set: { v in state.update { $0.customPrompt = v } })
    }

    private var polishHotkeyBinding: Binding<HotkeyConfig> {
        Binding(get: { state.settings.hotkey }, set: { v in state.update { $0.hotkey = v } })
    }

    private var settingsHotkeyBinding: Binding<HotkeyConfig> {
        Binding(get: { state.settings.settingsHotkey }, set: { v in state.update { $0.settingsHotkey = v } })
    }

    private var showIconBinding: Binding<Bool> {
        Binding(get: { state.settings.showMenuBarIcon },
                set: { v in state.setMenuBarIconVisible(v) })
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
