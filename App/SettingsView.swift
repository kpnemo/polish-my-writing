import SwiftUI
import PolishCore

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var apiKeyDraft: String = ""
    @State private var showAdvanced = false

    var body: some View {
        Form {
            Section("Provider") {
                Picker("Provider", selection: providerBinding) {
                    ForEach(Provider.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                SecureField("API Key", text: $apiKeyDraft)
                    .onSubmit { state.setAPIKey(apiKeyDraft, for: state.settings.provider) }
                Button("Save Key") {
                    state.setAPIKey(apiKeyDraft, for: state.settings.provider)
                }
            }

            Section("Polishing") {
                Picker("Level", selection: levelBinding) {
                    ForEach(PolishLevel.allCases, id: \.self) { l in
                        Text(l.displayName).tag(l)
                    }
                }
            }

            Section("General") {
                Toggle("Show menu bar icon", isOn: showIconBinding)
                Toggle("Launch at login", isOn: launchBinding)
                if !PermissionsManager.hasAccessibility() {
                    Button("Grant Accessibility Permission…") {
                        PermissionsManager.requestAccessibility()
                    }
                    .foregroundStyle(.orange)
                }
            }

            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                TextField("Model", text: modelBinding)
                Button("Reset to default model") {
                    state.update { $0.model = $0.provider.defaultModel }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
        .onAppear { apiKeyDraft = state.apiKey(for: state.settings.provider) }
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
                apiKeyDraft = state.apiKey(for: newProvider)
            }
        )
    }

    private var levelBinding: Binding<PolishLevel> {
        Binding(get: { state.settings.level }, set: { v in state.update { $0.level = v } })
    }

    private var modelBinding: Binding<String> {
        Binding(get: { state.settings.model }, set: { v in state.update { $0.model = v } })
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
