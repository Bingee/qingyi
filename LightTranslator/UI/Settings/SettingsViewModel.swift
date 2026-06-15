import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedModelID = TranslationModel.defaultSelectedID
    @Published var readClipboardOnOpen = AppSettings.defaults.readClipboardOnOpen
    @Published var hotkey = HotkeyConfig.default

    private let settingsStore: AppSettingsStore

    var availableModels: [TranslationModel] {
        TranslationModel.supported
    }

    init(settingsStore: AppSettingsStore) {
        self.settingsStore = settingsStore
        load()
    }

    func load() {
        let settings = settingsStore.load()
        selectedModelID = settings.selectedModelID
        readClipboardOnOpen = settings.readClipboardOnOpen
        hotkey = settings.hotkey
    }

    func isModelSelected(_ model: TranslationModel) -> Bool {
        selectedModelID == model.id
    }

    func selectModel(_ model: TranslationModel) {
        guard selectedModelID != model.id else {
            return
        }

        selectedModelID = model.id
        save()
    }

    func save() {
        let settings = AppSettings(
            selectedModelID: selectedModelID,
            translationServiceBaseURL: settingsStore.load().translationServiceBaseURL,
            defaultSourceLanguage: .auto,
            defaultTargetLanguage: .auto,
            readClipboardOnOpen: readClipboardOnOpen,
            hotkey: hotkey
        )

        settingsStore.save(settings)
        NotificationCenter.default.post(name: .hotkeySettingsDidChange, object: nil)
    }
}
