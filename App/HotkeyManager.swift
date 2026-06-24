import AppKit
import Carbon.HIToolbox
import PolishCore

/// Registers one or more global hotkeys via Carbon and dispatches each to its
/// callback by id. A single shared event handler serves all registered hotkeys.
final class HotkeyManager {
    private struct Registered {
        var ref: EventHotKeyRef?
        var onFire: () -> Void
    }

    private var hotkeys: [UInt32: Registered] = [:]
    private var eventHandler: EventHandlerRef?
    private let signature = OSType(0x504C5357) // 'PLSW'

    /// Registers `config` under `id`, replacing any existing hotkey for that id.
    /// Returns `true` on success; `false` if the shortcut is already claimed.
    @discardableResult
    func register(id: UInt32, _ config: HotkeyConfig, onFire: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()
        unregister(id: id)

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(
            config.keyCode, carbonModifiers(config), hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        let ok = status == noErr && ref != nil
        if ok {
            hotkeys[id] = Registered(ref: ref, onFire: onFire)
        } else {
            NSLog("HotkeyManager: registration failed for id \(id) (status=\(status))")
        }
        return ok
    }

    func unregister(id: UInt32) {
        if let existing = hotkeys[id], let ref = existing.ref {
            UnregisterEventHotKey(ref)
        }
        hotkeys[id] = nil
    }

    func unregisterAll() {
        for id in Array(hotkeys.keys) { unregister(id: id) }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return noErr }
            var hkID = EventHotKeyID()
            let err = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID
            )
            guard err == noErr else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.hotkeys[hkID.id]?.onFire()
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)
    }

    private func carbonModifiers(_ config: HotkeyConfig) -> UInt32 {
        var flags: UInt32 = 0
        if config.command { flags |= UInt32(cmdKey) }
        if config.option { flags |= UInt32(optionKey) }
        if config.shift { flags |= UInt32(shiftKey) }
        if config.control { flags |= UInt32(controlKey) }
        return flags
    }

    deinit { unregisterAll() }
}
