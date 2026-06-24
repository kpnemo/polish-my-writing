import AppKit
import Carbon.HIToolbox
import PolishCore

/// Registers a single global hotkey via Carbon RegisterEventHotKey and invokes a callback.
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onFire: (() -> Void)?
    private let signature = OSType(0x504C5357) // 'PLSW'

    func register(_ config: HotkeyConfig, onFire: @escaping () -> Void) {
        unregister()
        self.onFire = onFire

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onFire?()
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(
            config.keyCode,
            carbonModifiers(config),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKeyRef = nil
        eventHandler = nil
    }

    private func carbonModifiers(_ config: HotkeyConfig) -> UInt32 {
        var flags: UInt32 = 0
        if config.command { flags |= UInt32(cmdKey) }
        if config.option { flags |= UInt32(optionKey) }
        if config.shift { flags |= UInt32(shiftKey) }
        if config.control { flags |= UInt32(controlKey) }
        return flags
    }

    deinit { unregister() }
}
