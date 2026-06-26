import AppKit
import SwiftUI

/// Owns a single AppKit-hosted Accessibility onboarding window. Mirrors
/// `SettingsWindowController`: managing the window directly (instead of a SwiftUI
/// scene) lets us reliably open it and bring it to the front in a menu-bar /
/// LSUIElement app, and — like the Settings window — it never changes
/// `NSApp.activationPolicy` (which would make the MenuBarExtra icon disappear).
@MainActor
final class AccessibilityWindowController: NSObject {
    private var window: NSWindow?

    func show(openSettings: @escaping () -> Void, restart: @escaping () -> Void) {
        if window == nil {
            let hosting = NSHostingController(
                rootView: AccessibilityOnboardingView(openSettings: openSettings, restart: restart)
            )
            // Do NOT let the hosting controller drive the window size from the
            // SwiftUI ideal size — that produces an unstable size negotiation
            // (window resizes content resizes window…), which spins the CPU and
            // renders an empty window. We set a fixed size instead.
            hosting.sizingOptions = []
            let w = NSWindow(contentViewController: hosting)
            w.title = "Enable Polish My Writing"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 480, height: 340))
            w.center()
            window = w
        }

        guard let window else { return }
        if !window.isVisible { window.center() }
        surfaceToFront(window)
        // Re-assert shortly after — see SettingsWindowController for the rationale
        // (a single launch-time activation can be dropped before the app settles).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.surfaceCurrent() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in self?.surfaceCurrent() }
    }

    private func surfaceCurrent() {
        guard let window, window.isVisible else { return }
        surfaceToFront(window)
    }

    /// Bring the app + window to the front. `ignoringOtherApps: true` is needed
    /// because at launch there is no user gesture, so the cooperative
    /// `NSApp.activate()` is ignored (matches the existing `Notifier` pattern).
    private func surfaceToFront(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
