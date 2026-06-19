import Foundation

final class AppSettingsStore {
    private enum Keys {
        static let selectedModelID = "settings.selectedModelID"
        static let enabledModelIDs = "settings.enabledModelIDs"
        static let modelOrderIDs = "settings.modelOrderIDs"
        static let translationServiceBaseURL = "settings.translationServiceBaseURL"
        static let defaultSourceLanguage = "settings.defaultSourceLanguage"
        static let defaultTargetLanguage = "settings.defaultTargetLanguage"
        static let readClipboardOnOpen = "settings.readClipboardOnOpen"
        static let anonymousAnalyticsEnabled = "settings.anonymousAnalyticsEnabled"
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
        let enabledModelIDs = loadEnabledModelIDs()
        return AppSettings(
            selectedModelID: loadSelectedModelID(enabledModelIDs: enabledModelIDs),
            enabledModelIDs: enabledModelIDs,
            modelOrderIDs: loadModelOrderIDs(),
            translationServiceBaseURL: loadTranslationServiceBaseURL(),
            defaultSourceLanguage: language(for: Keys.defaultSourceLanguage, fallback: .auto),
            defaultTargetLanguage: language(for: Keys.defaultTargetLanguage, fallback: .auto),
            readClipboardOnOpen: defaults.object(forKey: Keys.readClipboardOnOpen) as? Bool
                ?? AppSettings.defaults.readClipboardOnOpen,
            anonymousAnalyticsEnabled: defaults.object(forKey: Keys.anonymousAnalyticsEnabled) as? Bool
                ?? AppSettings.defaults.anonymousAnalyticsEnabled,
            hotkey: loadHotkey()
        )
    }

    func save(_ settings: AppSettings) {
        let enabledModelIDs = normalizedModelIDs(settings.enabledModelIDs)
        let modelOrderIDs = normalizedModelIDs(settings.modelOrderIDs, includeMissing: true)
        let selectedModelID = enabledModelIDs.first ?? settings.selectedModelID
        defaults.set(selectedModelID, forKey: Keys.selectedModelID)
        defaults.set(enabledModelIDs, forKey: Keys.enabledModelIDs)
        defaults.set(modelOrderIDs, forKey: Keys.modelOrderIDs)
        defaults.set(settings.translationServiceBaseURL, forKey: Keys.translationServiceBaseURL)
        defaults.set(settings.defaultSourceLanguage.rawValue, forKey: Keys.defaultSourceLanguage)
        defaults.set(settings.defaultTargetLanguage.rawValue, forKey: Keys.defaultTargetLanguage)
        defaults.set(settings.readClipboardOnOpen, forKey: Keys.readClipboardOnOpen)
        defaults.set(settings.anonymousAnalyticsEnabled, forKey: Keys.anonymousAnalyticsEnabled)
        defaults.set(Int(settings.hotkey.keyCode), forKey: Keys.hotkeyKeyCode)
        defaults.set(Int(settings.hotkey.carbonModifiers), forKey: Keys.hotkeyModifiers)
        defaults.set(settings.hotkey.displayName, forKey: Keys.hotkeyDisplayName)
        defaults.set(settings.hotkey.enabled, forKey: Keys.hotkeyEnabled)
    }

    func loadCustomModelConfig(for modelID: String) -> CustomModelConfig {
        let savedBaseURL = defaults.string(forKey: customModelKey("baseURL", modelID: modelID))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = savedBaseURL?.isEmpty == false
            ? savedBaseURL ?? ""
            : TranslationModel.model(for: modelID).defaultBaseURL ?? ""

        return CustomModelConfig(
            baseURL: baseURL,
            modelID: defaults.string(forKey: customModelKey("modelID", modelID: modelID))
                ?? TranslationModel.model(for: modelID).defaultProviderModelID
        )
    }

    func saveCustomModelConfig(_ config: CustomModelConfig, for modelID: String) {
        defaults.set(config.baseURL, forKey: customModelKey("baseURL", modelID: modelID))
        defaults.set(config.modelID, forKey: customModelKey("modelID", modelID: modelID))
    }

    private func loadSelectedModelID(enabledModelIDs: [String]) -> String {
        if let firstEnabled = enabledModelIDs.first {
            return firstEnabled
        }

        if let modelID = defaults.string(forKey: Keys.selectedModelID),
           TranslationModel.supported.contains(where: { $0.id == modelID }) {
            return modelID
        }

        return AppSettings.defaults.selectedModelID
    }

    private func loadEnabledModelIDs() -> [String] {
        let savedModelIDs = defaults.stringArray(forKey: Keys.enabledModelIDs) ?? []
        let normalizedSavedModelIDs = normalizedModelIDs(savedModelIDs)
        if !normalizedSavedModelIDs.isEmpty {
            return normalizedSavedModelIDs
        }

        if let selectedModelID = defaults.string(forKey: Keys.selectedModelID),
           TranslationModel.supported.contains(where: { $0.id == selectedModelID }) {
            return [selectedModelID]
        }

        return AppSettings.defaults.enabledModelIDs
    }

    private func loadModelOrderIDs() -> [String] {
        let savedModelIDs = defaults.stringArray(forKey: Keys.modelOrderIDs) ?? []
        let normalizedSavedModelIDs = normalizedModelIDs(savedModelIDs, includeMissing: true)
        if !normalizedSavedModelIDs.isEmpty {
            return normalizedSavedModelIDs
        }

        return normalizedModelIDs(TranslationModel.supported.map(\.id), includeMissing: true)
    }

    private func loadTranslationServiceBaseURL() -> String {
        guard let savedBaseURL = defaults.string(forKey: Keys.translationServiceBaseURL) else {
            return AppSettings.defaults.translationServiceBaseURL
        }

        let normalizedBaseURL = savedBaseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        switch normalizedBaseURL {
        case "",
             "http://127.0.0.1:8791",
             "http://127.0.0.1:8792",
             "http://localhost:8791",
             "http://localhost:8792":
            return AppSettings.defaults.translationServiceBaseURL
        default:
            return normalizedBaseURL
        }
    }

    private func normalizedModelIDs(_ modelIDs: [String], includeMissing: Bool = false) -> [String] {
        let supportedIDs = Set(TranslationModel.supported.map(\.id))
        var seen = Set<String>()
        var normalized = modelIDs.filter { modelID in
            guard supportedIDs.contains(modelID), !seen.contains(modelID) else {
                return false
            }
            seen.insert(modelID)
            return true
        }

        if includeMissing {
            for modelID in TranslationModel.supported.map(\.id) where !seen.contains(modelID) {
                normalized.append(modelID)
            }
        }

        return normalized
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

    private func customModelKey(_ field: String, modelID: String) -> String {
        "settings.customModel.\(modelID).\(field)"
    }
}

struct CustomModelConfig: Equatable {
    var baseURL: String
    var modelID: String
}

final class TranslationHistoryStore {
    private let maxEntries = 100
    private let fileManager: FileManager
    private let historyURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("LightTranslator", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("LightTranslator", isDirectory: true)
        historyURL = supportDirectory.appendingPathComponent("translation-history.json")

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [TranslationHistoryEntry] {
        guard let data = try? Data(contentsOf: historyURL) else {
            return []
        }

        return ((try? decoder.decode([TranslationHistoryEntry].self, from: data)) ?? [])
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(maxEntries)
            .map { $0 }
    }

    func add(_ entry: TranslationHistoryEntry) {
        var entries = load()
        entries.removeAll { $0.id == entry.id }
        entries.insert(entry, at: 0)
        save(Array(entries.prefix(maxEntries)))
    }

    func delete(id: UUID) {
        save(load().filter { $0.id != id })
    }

    private func save(_ entries: [TranslationHistoryEntry]) {
        do {
            try fileManager.createDirectory(
                at: historyURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(entries)
            try data.write(to: historyURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save translation history: \(error.localizedDescription)")
        }
    }
}
