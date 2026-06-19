import Foundation

struct AppSettings: Equatable {
    var selectedModelID: String
    var enabledModelIDs: [String]
    var modelOrderIDs: [String]
    var translationServiceBaseURL: String
    var defaultSourceLanguage: LanguageOption
    var defaultTargetLanguage: LanguageOption
    var readClipboardOnOpen: Bool
    var anonymousAnalyticsEnabled: Bool
    var hotkey: HotkeyConfig

    static let defaults = AppSettings(
        selectedModelID: TranslationModel.defaultSelectedID,
        enabledModelIDs: [TranslationModel.defaultSelectedID],
        modelOrderIDs: TranslationModel.supported.map(\.id),
        translationServiceBaseURL: "https://qingyi-api.tuhuo3.com",
        defaultSourceLanguage: .auto,
        defaultTargetLanguage: .auto,
        readClipboardOnOpen: false,
        anonymousAnalyticsEnabled: true,
        hotkey: .default
    )
}
