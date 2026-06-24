import AppKit
import SwiftUI

/// Owns a single AppKit-hosted Settings window. Managing the window directly
/// (instead of SwiftUI's `Settings` scene) lets us reliably open it and force it
/// to the front in a menu-bar / LSUIElement app, where the scene-based opener is
/// unreliable.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show<Content: View>(@ViewBuilder _ content: () -> Content) {
        if window == nil {
            let hosting = NSHostingController(rootView: content())
            let w = NSWindow(contentViewController: hosting)
            w.title = "Polish My Writing Settings"
            w.styleMask = [.titled, .closable, .resizable]
            w.isReleasedWhenClosed = false
            w.delegate = self
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
