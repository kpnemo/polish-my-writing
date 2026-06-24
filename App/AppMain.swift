import SwiftUI
import PolishCore

@main
struct PolishMyWritingApp: App {
    @StateObject private var state = AppState()
    @Environment(\.openSettings) private var openSettingsEnv

    var body: some Scene {
        MenuBarExtra(
            "Polish My Writing",
            systemImage: "wand.and.stars",
            isInserted: .constant(true)
        ) {
            Picker("Level", selection: Binding(
                get: { state.settings.level },
                set: { v in state.update { $0.level = v } }
            )) {
                ForEach(PolishLevel.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Divider()
            SettingsLink { Text("Settings…") }
                .keyboardShortcut(",")
            Button("Quit Polish My Writing") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }

        Settings {
            SettingsView(state: state)
                .onAppear {
                    state.openSettings = { openSettingsEnv() }
                    state.start()
                }
        }
    }
}
