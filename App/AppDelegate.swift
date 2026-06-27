import AppKit

/// Owns `AppState` for a pure menu-bar (LSUIElement) app. Creating it here in
/// `applicationDidFinishLaunching` — instead of as a SwiftUI `@StateObject` —
/// guarantees the app's wiring and status item come up at launch even though
/// there is no SwiftUI scene to render. (A `MenuBarExtra`-less SwiftUI `App`
/// would never initialize a `@StateObject`, so the hotkeys and launch gate
/// would never run.)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        state.installMenuBar()
        appState = state
    }
}
