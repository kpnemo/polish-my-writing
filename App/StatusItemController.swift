import AppKit

/// A menu item that runs a closure when chosen — lets us build the status-bar
/// menu from app state without scattering `@objc` selectors.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, state: NSControl.StateValue = .off, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        self.target = self
        self.state = state
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func fire() { handler() }
}

/// Owns the app's `NSStatusItem` directly instead of relying on SwiftUI's
/// `MenuBarExtra`, whose status item macOS silently drops across sleep/wake,
/// long uptime, and display reconfiguration — with no SwiftUI recovery path
/// (the cause of the "icon vanished, Settings won't open" bug). Because we own
/// the item, we can recreate it on those events and the icon survives.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var shouldShow: Bool
    /// Populates a (freshly emptied) menu with the current app state. Called on
    /// every open via the menu delegate, so checkmarks always reflect reality.
    private let buildMenu: (NSMenu) -> Void
    private var wakeObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var healthTimer: Timer?

    init(visible: Bool, buildMenu: @escaping (NSMenu) -> Void) {
        self.shouldShow = visible
        self.buildMenu = buildMenu
        super.init()
    }

    /// Creates the item (if visible) and starts watching for the events that
    /// drop it.
    func install() {
        if shouldShow { createItem() }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reassert(reason: "wake") }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reassert(reason: "screen-change") }
        }

        // Safety net for the "long uptime" silent drop, which posts no wake or
        // screen notification: periodically verify the item is still live and
        // recreate it if macOS dropped it. Cheap, and only recreates on failure
        // so there's no flicker in the normal case.
        let timer = Timer(timeInterval: 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.healIfNeeded() }
        }
        RunLoop.main.add(timer, forMode: .common)
        healthTimer = timer
    }

    /// Show or hide the icon (the "Show menu bar icon" toggle).
    func setVisible(_ visible: Bool) {
        guard visible != shouldShow else { return }
        shouldShow = visible
        if visible { createItem() } else { removeItem() }
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        buildMenu(menu)
    }

    // MARK: - Internals

    private func createItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "pencil.and.scribble",
                accessibilityDescription: "Polish My Writing"
            )
            image?.isTemplate = true
            button.image = image
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        NSLog("PMW: status item created")
    }

    private func removeItem() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
        NSLog("PMW: status item removed")
    }

    /// Force a fresh item after a sleep/wake or display change. macOS can drop
    /// the item while leaving our reference intact, so we recreate
    /// unconditionally rather than trust `statusItem != nil`.
    private func reassert(reason: String) {
        NSLog("PMW: re-asserting status item (\(reason)); shouldShow=\(shouldShow)")
        guard shouldShow else { return }
        removeItem()
        createItem()
    }

    /// Periodic liveness check: a dropped item loses its button's window. Only
    /// recreates when the item is actually gone, so the steady state is a no-op.
    private func healIfNeeded() {
        guard shouldShow else { return }
        let healthy = statusItem?.button?.window != nil
        guard !healthy else { return }
        NSLog("PMW: status item not healthy on periodic check; recreating")
        removeItem()
        createItem()
    }
}
