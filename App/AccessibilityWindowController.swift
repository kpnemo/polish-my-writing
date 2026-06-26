import AppKit
import SwiftUI

/// Owns a single AppKit-hosted Accessibility onboarding window. Mirrors
/// `SettingsWindowController`: managing the window directly (instead of a SwiftUI
/// scene) lets us reliably open it and force it to the front in a menu-bar /
/// LSUIElement app.
@MainActor
final class AccessibilityWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    /// Whether the window is currently on screen.
    var isVisible: Bool { window?.isVisible ?? false }

    /// Called when the window is closing. Lets the owner coordinate the app's
    /// activation policy across multiple windows; if unset, the controller falls
    /// back to reverting to accessory on its own.
    var onWillClose: (() -> Void)?

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

        guard let window else { return }
        if !window.isVisible { window.center() }
        surfaceToFront(window)
        // Re-assert shortly after — see SettingsWindowController for the rationale
        // (a single launch-time activation can be dropped before the app settles).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.surfaceCurrent() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in self?.surfaceCurrent() }
    }

    private func surfaceCurrent() {
        guard let window else { return }
        surfaceToFront(window)
    }

    /// Force the app and its window to the foreground. `ignoringOtherApps: true`
    /// is required because at launch there is no user gesture, so the cooperative
    /// `NSApp.activate()` is ignored and the window would stay behind the
    /// previously frontmost app (matches the existing `Notifier` pattern).
    private func surfaceToFront(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        if let onWillClose {
            onWillClose()
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
