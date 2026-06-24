import AppKit
import UserNotifications
import PolishCore

/// Posts banner notifications and opens the Settings window. Conforms to PolishCore.UserNotifying.
final class Notifier: UserNotifying {
    private let openSettingsAction: () -> Void

    init(openSettings: @escaping () -> Void) {
        self.openSettingsAction = openSettings
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    func notify(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Polish My Writing"
        content.body = message
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func openSettings() {
        DispatchQueue.main.async { [openSettingsAction] in
            NSApp.activate(ignoringOtherApps: true)
            openSettingsAction()
        }
    }
}
