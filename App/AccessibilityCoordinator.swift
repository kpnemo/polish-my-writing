import AppKit

/// Drives the one-click Accessibility setup: prompts for permission, then polls
/// until the grant lands and relaunches so the new process starts fully trusted.
@MainActor
final class AccessibilityCoordinator {
    private var pollTimer: Timer?
    private var deadline: Date?

    /// If Accessibility is already trusted, does nothing. Otherwise shows the
    /// system prompt, notifies the user, and starts polling. When the grant is
    /// detected the app relaunches automatically; if it isn't granted within
    /// 180s the poll stops.
    func requestAndAutoRelaunch(notify: @escaping (String) -> Void) {
        if PermissionsManager.hasAccessibility() { return }

        _ = PermissionsManager.requestAccessibility() // shows the system prompt
        notify("Grant Accessibility to Polish My Writing — it will restart automatically and be ready.")

        // Guard against starting a second timer if invoked again while polling.
        guard pollTimer == nil else { return }

        deadline = Date().addingTimeInterval(180)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if PermissionsManager.hasAccessibility() {
                    self.stop()
                    Relauncher.relaunch()
                } else if let deadline = self.deadline, Date() >= deadline {
                    self.stop()
                }
            }
        }
    }

    private func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        deadline = nil
    }
}
