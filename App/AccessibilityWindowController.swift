import AppKit
import SwiftUI

/// Owns a single AppKit-hosted Accessibility onboarding window. Mirrors
/// `SettingsWindowController`: managing the window directly (instead of a SwiftUI
/// scene) lets us reliably open it and force it to the front in a menu-bar /
/// LSUIElement app.
@MainActor
final class AccessibilityWindowController: NSObject, NSWindowDelegate {
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
            w.delegate = self
            w.setContentSize(NSSize(width: 480, height: 340))
            w.center()
            window = w
        }

        // Become a regular app while the window is open so it can be frontmost and
        // focused; revert to accessory (menu-bar-only) when it closes.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        guard let window else { return }
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
