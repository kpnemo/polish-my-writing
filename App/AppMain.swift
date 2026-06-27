import SwiftUI

@main
struct PolishMyWritingApp: App {
    // The status item and all app wiring live in AppDelegate/AppState, not in a
    // SwiftUI scene — see AppDelegate for why. The Settings scene is an empty
    // placeholder so the `App` protocol is satisfied; the real Settings window
    // is an AppKit window managed by SettingsWindowController.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
