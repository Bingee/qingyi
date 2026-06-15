import Foundation

struct AppSettings: Equatable {
    var baseURL: String
    var modelName: String
    var defaultSourceLanguage: LanguageOption
    var defaultTargetLanguage: LanguageOption
    var readClipboardOnOpen: Bool
    var hotkey: HotkeyConfig

    static let defaults = AppSettings(
        baseURL: "",
        modelName: "",
        defaultSourceLanguage: .auto,
        defaultTargetLanguage: .auto,
        readClipboardOnOpen: true,
        hotkey: .default
    )
}
