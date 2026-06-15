import AppKit

final class ClipboardManager {
    func readText() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
