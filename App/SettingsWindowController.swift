import AppKit
import SwiftUI

/// Owns a single AppKit-hosted Settings window. Managing the window directly
/// (instead of SwiftUI's `Settings` scene) lets us reliably open it and force it
/// to the front in a menu-bar / LSUIElement app, where the scene-based opener is
/// unreliable.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    /// Whether the window is currently on screen.
    var isVisible: Bool { window?.isVisible ?? false }

    /// Called when the window is closing. Lets the owner coordinate the app's
    /// activation policy across multiple windows; if unset, the controller falls
    /// back to reverting to accessory on its own.
    var onWillClose: (() -> Void)?

    func show<Content: View>(@ViewBuilder _ content: () -> Content) {
        if window == nil {
            let hosting = NSHostingController(rootView: content())
            // Do NOT let the hosting controller drive the window size from the
            // SwiftUI ideal size — with a Form that produces an unstable size
            // negotiation (window resizes content resizes window…), which spins
            // the CPU and renders an empty window. We set a fixed size instead.
            hosting.sizingOptions = []
            let w = NSWindow(contentViewController: hosting)
            w.title = "Polish My Writing Settings"
            w.styleMask = [.titled, .closable, .resizable]
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.setContentSize(NSSize(width: 480, height: 600))
            w.contentMinSize = NSSize(width: 420, height: 360)
            w.center()
            window = w
        }

        // Become a regular app while the window is open so it can be frontmost and
        // focused; revert to accessory (menu-bar-only) when it closes.
        NSApp.setActivationPolicy(.regular)
        guard let window else { return }
        if !window.isVisible { window.center() }
        surfaceToFront(window)
        // Re-assert shortly after: at launch (LaunchServices) a
        // single activation can be dropped or overridden before the app is fully
        // settled, leaving the window behind. Re-running once the run loop has
        // turned a few times reliably brings it forward.
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
    /// previously frontmost app (deprecated on macOS 14 but still the dependable
    /// path; matches the existing `Notifier` pattern).
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
