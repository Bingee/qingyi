import Foundation

final class AppSettingsStore {
    private enum Keys {
        static let selectedModelID = "settings.selectedModelID"
        static let legacyEnabledModelIDs = "settings.enabledModelIDs"
        static let translationServiceBaseURL = "settings.translationServiceBaseURL"
        static let defaultSourceLanguage = "settings.defaultSourceLanguage"
        static let defaultTargetLanguage = "settings.defaultTargetLanguage"
        static let readClipboardOnOpen = "settings.readClipboardOnOpen"
        static let hotkeyKeyCode = "settings.hotkey.keyCode"
        static let hotkeyModifiers = "settings.hotkey.modifiers"
        static let hotkeyDisplayName = "settings.hotkey.displayName"
        static let hotkeyEnabled = "settings.hotkey.enabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        AppSettings(
            selectedModelID: loadSelectedModelID(),
            translationServiceBaseURL: defaults.string(forKey: Keys.translationServiceBaseURL)
                ?? AppSettings.defaults.translationServiceBaseURL,
            defaultSourceLanguage: language(for: Keys.defaultSourceLanguage, fallback: .auto),
            defaultTargetLanguage: language(for: Keys.defaultTargetLanguage, fallback: .auto),
            readClipboardOnOpen: defaults.object(forKey: Keys.readClipboardOnOpen) as? Bool
                ?? AppSettings.defaults.readClipboardOnOpen,
            hotkey: loadHotkey()
        )
    }

    func save(_ settings: AppSettings) {
        defaults.set(settings.selectedModelID, forKey: Keys.selectedModelID)
        defaults.set(settings.translationServiceBaseURL, forKey: Keys.translationServiceBaseURL)
        defaults.set(settings.defaultSourceLanguage.rawValue, forKey: Keys.defaultSourceLanguage)
        defaults.set(settings.defaultTargetLanguage.rawValue, forKey: Keys.defaultTargetLanguage)
        defaults.set(settings.readClipboardOnOpen, forKey: Keys.readClipboardOnOpen)
        defaults.set(Int(settings.hotkey.keyCode), forKey: Keys.hotkeyKeyCode)
        defaults.set(Int(settings.hotkey.carbonModifiers), forKey: Keys.hotkeyModifiers)
        defaults.set(settings.hotkey.displayName, forKey: Keys.hotkeyDisplayName)
        defaults.set(settings.hotkey.enabled, forKey: Keys.hotkeyEnabled)
    }

    private func loadSelectedModelID() -> String {
        if let modelID = defaults.string(forKey: Keys.selectedModelID),
           TranslationModel.supported.contains(where: { $0.id == modelID }) {
            return modelID
        }

        let legacyModelIDs = defaults.stringArray(forKey: Keys.legacyEnabledModelIDs) ?? []
        if let migratedModelID = TranslationModel.supported.first(where: { legacyModelIDs.contains($0.id) })?.id {
            return migratedModelID
        }

        return AppSettings.defaults.selectedModelID
    }

    private func language(for key: String, fallback: LanguageOption) -> LanguageOption {
        guard
            let value = defaults.string(forKey: key),
            let language = LanguageOption(rawValue: value)
        else {
            return fallback
        }
        return language
    }

    private func loadHotkey() -> HotkeyConfig {
        let defaultHotkey = AppSettings.defaults.hotkey
        let keyCodeObject = defaults.object(forKey: Keys.hotkeyKeyCode)
        let modifiersObject = defaults.object(forKey: Keys.hotkeyModifiers)

        guard
            let keyCode = keyCodeObject as? Int,
            let modifiers = modifiersObject as? Int
        else {
            return defaultHotkey
        }

        return HotkeyConfig(
            keyCode: UInt32(keyCode),
            carbonModifiers: UInt32(modifiers),
            displayName: defaults.string(forKey: Keys.hotkeyDisplayName) ?? defaultHotkey.displayName,
            enabled: defaults.object(forKey: Keys.hotkeyEnabled) as? Bool ?? true
        )
    }
}
