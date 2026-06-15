import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var baseURL = ""
    @Published var apiKey = ""
    @Published var modelName = ""
    @Published var readClipboardOnOpen = true
    @Published var hotkey = HotkeyConfig.default
    @Published var message = ""
    @Published var errorMessage = ""

    private let settingsStore: AppSettingsStore
    private let keychainStore: KeychainStore

    init(settingsStore: AppSettingsStore, keychainStore: KeychainStore) {
        self.settingsStore = settingsStore
        self.keychainStore = keychainStore
        load()
    }

    func load() {
        let settings = settingsStore.load()
        baseURL = settings.baseURL
        modelName = settings.modelName
        readClipboardOnOpen = settings.readClipboardOnOpen
        hotkey = settings.hotkey
        apiKey = (try? keychainStore.loadAPIKey()) ?? ""
    }

    func save() {
        message = ""
        errorMessage = ""

        let settings = AppSettings(
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            modelName: modelName.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultSourceLanguage: .auto,
            defaultTargetLanguage: .auto,
            readClipboardOnOpen: readClipboardOnOpen,
            hotkey: hotkey
        )

        do {
            settingsStore.save(settings)
            try keychainStore.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            NotificationCenter.default.post(name: .hotkeySettingsDidChange, object: nil)
            message = "已保存"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
