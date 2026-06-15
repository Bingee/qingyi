import AppKit
import Carbon

struct HotkeyConfig: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var displayName: String
    var enabled: Bool

    static let `default` = HotkeyConfig(
        keyCode: UInt32(kVK_Space),
        carbonModifiers: UInt32(optionKey),
        displayName: "⌥ Space",
        enabled: true
    )

    init(
        keyCode: UInt32,
        carbonModifiers: UInt32,
        displayName: String,
        enabled: Bool = true
    ) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.displayName = displayName
        self.enabled = enabled
    }

    init?(event: NSEvent) {
        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else {
            return nil
        }

        keyCode = UInt32(event.keyCode)
        carbonModifiers = modifiers
        enabled = true
        displayName = Self.displayName(
            keyCode: UInt32(event.keyCode),
            modifierFlags: event.modifierFlags,
            characters: event.charactersIgnoringModifiers
        )
    }

    static func displayName(
        keyCode: UInt32,
        modifierFlags: NSEvent.ModifierFlags,
        characters: String?
    ) -> String {
        let modifierText = [
            modifierFlags.contains(.control) ? "⌃" : nil,
            modifierFlags.contains(.option) ? "⌥" : nil,
            modifierFlags.contains(.shift) ? "⇧" : nil,
            modifierFlags.contains(.command) ? "⌘" : nil
        ]
            .compactMap { $0 }
            .joined(separator: "")

        let keyText = specialKeyName(for: keyCode)
            ?? characters?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            ?? "Key \(keyCode)"

        return "\(modifierText) \(keyText)"
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0

        if flags.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            result |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            result |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            result |= UInt32(shiftKey)
        }

        return result
    }

    private static func specialKeyName(for keyCode: UInt32) -> String? {
        switch Int(keyCode) {
        case kVK_Space:
            return "Space"
        case kVK_Return:
            return "Return"
        case kVK_Tab:
            return "Tab"
        case kVK_Escape:
            return "Esc"
        case kVK_Delete:
            return "Delete"
        case kVK_LeftArrow:
            return "←"
        case kVK_RightArrow:
            return "→"
        case kVK_UpArrow:
            return "↑"
        case kVK_DownArrow:
            return "↓"
        default:
            return nil
        }
    }
}
