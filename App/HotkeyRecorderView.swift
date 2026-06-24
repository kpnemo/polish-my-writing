import SwiftUI
import PolishCore

/// A control that shows the current shortcut and, when clicked, records the next
/// key combination the user presses (a modifier is required; Esc cancels).
struct HotkeyRecorderView: View {
    let title: String
    @Binding var hotkey: HotkeyConfig
    /// Called with `true` when recording starts and `false` when it ends, so the
    /// owner can suspend global hotkeys during capture.
    var onRecordingChange: ((Bool) -> Void)? = nil

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(recording ? "Press shortcut…" : hotkey.displayString) {
                recording ? stop() : start()
            }
            .frame(minWidth: 130)
            .help(recording ? "Press a shortcut with at least one modifier, or Esc to cancel" : "Click to change")
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        onRecordingChange?(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc cancels
                stop()
                return nil
            }
            let mods = event.modifierFlags
            let command = mods.contains(.command)
            let option = mods.contains(.option)
            let control = mods.contains(.control)
            let shift = mods.contains(.shift)
            // Require at least one non-shift modifier so we don't capture bare keys.
            guard command || option || control else {
                NSSound.beep()
                return nil
            }
            hotkey = HotkeyConfig(
                keyCode: UInt32(event.keyCode),
                command: command, option: option, shift: shift, control: control
            )
            stop()
            return nil // swallow the event so it doesn't type into a field
        }
    }

    private func stop() {
        guard recording else { return }
        recording = false
        onRecordingChange?(false)
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
