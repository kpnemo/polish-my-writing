import SwiftUI

@main
struct PolishMyWritingApp: App {
    var body: some Scene {
        MenuBarExtra("Polish My Writing", systemImage: "wand.and.stars") {
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
