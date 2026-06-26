import AppKit
import SwiftUI

/// Owns a single AppKit-hosted Settings window. Managing the window directly
/// (instead of SwiftUI's `Settings` scene) lets us reliably open it and bring it
/// to the front in a menu-bar / LSUIElement app, where the scene-based opener is
/// unreliable.
///
/// IMPORTANT: this never changes `NSApp.activationPolicy`. Toggling a MenuBarExtra
/// app between `.accessory` and `.regular` (which we used to do on window
/// open/close) makes the menu-bar status item disappear after a few cycles. The
/// app stays `.accessory`; activating it is enough to surface and focus the
/// window.
@MainActor
final class SettingsWindowController: NSObject {
    private var window: NSWindow?

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
            w.setContentSize(NSSize(width: 480, height: 600))
            w.contentMinSize = NSSize(width: 420, height: 360)
            w.center()
            window = w
        }

        guard let window else { return }
        if !window.isVisible { window.center() }
        surfaceToFront(window)
        // Re-assert shortly after: at launch a single activation can be dropped
        // before the app is fully settled. Guarded on isVisible so a window the
        // user closed in the meantime is not re-opened.
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
