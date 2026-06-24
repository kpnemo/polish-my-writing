import AppKit
import ApplicationServices

enum PermissionsManager {
    /// True if the app is trusted for the Accessibility API (needed to post key events).
    static func hasAccessibility() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user (shows the system dialog that deep-links to Settings) if not trusted.
    @discardableResult
    static func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Opens the Accessibility pane in System Settings.
    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
