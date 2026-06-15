import Foundation

struct AppSettings: Equatable {
    var selectedModelID: String
    var translationServiceBaseURL: String
    var defaultSourceLanguage: LanguageOption
    var defaultTargetLanguage: LanguageOption
    var readClipboardOnOpen: Bool
    var hotkey: HotkeyConfig

    static let defaults = AppSettings(
        selectedModelID: TranslationModel.defaultSelectedID,
        translationServiceBaseURL: "http://127.0.0.1:8791",
        defaultSourceLanguage: .auto,
        defaultTargetLanguage: .auto,
        readClipboardOnOpen: false,
        hotkey: .default
    )
}
