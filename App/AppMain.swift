import SwiftUI
import PolishCore

@main
struct PolishMyWritingApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra(
            "Polish My Writing",
            systemImage: "pencil.and.scribble",
            isInserted: Binding(
                get: { state.settings.showMenuBarIcon },
                set: { v in state.update { $0.showMenuBarIcon = v } }
            )
        ) {
            Picker("Level", selection: Binding(
                get: { state.settings.level },
                set: { v in state.update { $0.level = v } }
            )) {
                ForEach(PolishLevel.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Divider()
            Button("Settings…") { state.openSettings() }
                .keyboardShortcut(",")
            Button("Quit Polish My Writing") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }

        Settings {
            SettingsView(state: state)
        }
    }
}
