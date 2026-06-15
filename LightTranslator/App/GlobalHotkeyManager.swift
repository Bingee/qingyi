import AppKit
import Carbon

@MainActor
final class GlobalHotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let settingsStore: AppSettingsStore
    private let onTrigger: @MainActor () -> Void

    init(
        settingsStore: AppSettingsStore,
        onTrigger: @escaping @MainActor () -> Void
    ) {
        self.settingsStore = settingsStore
        self.onTrigger = onTrigger
    }

    func registerConfiguredHotkey() {
        unregister()

        let hotkey = settingsStore.load().hotkey
        guard hotkey.enabled else {
            return
        }

        let hotKeyID = EventHotKeyID(signature: fourCharCode("LTRY"), id: 1)
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            NSLog("Failed to register hotkey \(hotkey.displayName): \(status)")
            return
        }

        NSLog("Registered hotkey \(hotkey.displayName)")

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard
                    let event,
                    let userData
                else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if hotKeyID.id == 1 {
                    let managerAddress = UInt(bitPattern: userData)
                    Task { @MainActor in
                        guard let pointer = UnsafeMutableRawPointer(bitPattern: managerAddress) else {
                            return
                        }
                        let manager = Unmanaged<GlobalHotkeyManager>
                            .fromOpaque(pointer)
                            .takeUnretainedValue()
                        manager.onTrigger()
                    }
                }

                return noErr
            },
            1,
            &eventSpec,
            selfPointer,
            &eventHandler
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func fourCharCode(_ string: String) -> OSType {
        var result: OSType = 0
        for scalar in string.unicodeScalars.prefix(4) {
            result = (result << 8) + OSType(scalar.value)
        }
        return result
    }
}
