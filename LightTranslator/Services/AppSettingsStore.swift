import Foundation

final class AppSettingsStore {
    private enum Keys {
        static let baseURL = "settings.baseURL"
        static let modelName = "settings.modelName"
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
            baseURL: defaults.string(forKey: Keys.baseURL) ?? AppSettings.defaults.baseURL,
            modelName: defaults.string(forKey: Keys.modelName) ?? AppSettings.defaults.modelName,
            defaultSourceLanguage: language(for: Keys.defaultSourceLanguage, fallback: .auto),
            defaultTargetLanguage: language(for: Keys.defaultTargetLanguage, fallback: .auto),
            readClipboardOnOpen: defaults.object(forKey: Keys.readClipboardOnOpen) as? Bool ?? true,
            hotkey: loadHotkey()
        )
    }

    func save(_ settings: AppSettings) {
        defaults.set(settings.baseURL, forKey: Keys.baseURL)
        defaults.set(settings.modelName, forKey: Keys.modelName)
        defaults.set(settings.defaultSourceLanguage.rawValue, forKey: Keys.defaultSourceLanguage)
        defaults.set(settings.defaultTargetLanguage.rawValue, forKey: Keys.defaultTargetLanguage)
        defaults.set(settings.readClipboardOnOpen, forKey: Keys.readClipboardOnOpen)
        defaults.set(Int(settings.hotkey.keyCode), forKey: Keys.hotkeyKeyCode)
        defaults.set(Int(settings.hotkey.carbonModifiers), forKey: Keys.hotkeyModifiers)
        defaults.set(settings.hotkey.displayName, forKey: Keys.hotkeyDisplayName)
        defaults.set(settings.hotkey.enabled, forKey: Keys.hotkeyEnabled)
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
