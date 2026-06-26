import SwiftUI

struct AccessibilityOnboardingView: View {
    let openSettings: () -> Void
    let restart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Enable Polish My Writing").font(.title2).bold()
            Text("To replace your selected text, the app needs Accessibility permission. Two quick steps:")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Step 1 — Grant permission").font(.headline)
                Text("Open Accessibility settings and switch Polish My Writing on.")
                    .foregroundStyle(.secondary)
                Button("Open Accessibility Settings…", action: openSettings)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Step 2 — Restart").font(.headline)
                Text("Then click here to restart the app and finish.")
                    .foregroundStyle(.secondary)
                Button("Restart Polish My Writing", action: restart)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
