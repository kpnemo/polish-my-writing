import AppKit
import PolishCore

/// Real clipboard/keystroke capture. Conforms to PolishCore.TextCapturing.
final class TextCaptureService: TextCapturing {
    private let pasteboard = NSPasteboard.general
    private var savedItems: [NSPasteboardItem] = []

    func saveClipboard() {
        savedItems = pasteboard.pasteboardItems?.compactMap { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []
    }

    func copySelection() -> String? {
        // Capture the change count AFTER clearing, since clearContents() itself
        // bumps it — so a later change reliably means the frontmost app responded
        // to Cmd+C (rather than just our own clear).
        pasteboard.clearContents()
        let changeCountAfterClear = pasteboard.changeCount
        sendKey(keyCode: 8, command: true) // Cmd+C ('C' = 8)
        // Poll up to ~500ms so a slow app isn't mistaken for "no selection";
        // returns as soon as the app writes the pasteboard.
        var waitedMicros = 0
        while pasteboard.changeCount == changeCountAfterClear && waitedMicros < 500_000 {
            usleep(10_000)
            waitedMicros += 10_000
        }
        guard pasteboard.changeCount != changeCountAfterClear else { return nil }
        return pasteboard.string(forType: .string)
    }

    func pasteReplacement(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        usleep(20_000)
        sendKey(keyCode: 9, command: true) // Cmd+V ('V' = 9)
        usleep(120_000)
    }

    func restoreClipboard() {
        pasteboard.clearContents()
        if !savedItems.isEmpty {
            pasteboard.writeObjects(savedItems)
        }
        savedItems = []
    }

    private func sendKey(keyCode: CGKeyCode, command: Bool) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        if command {
            down?.flags = .maskCommand
            up?.flags = .maskCommand
        }
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
