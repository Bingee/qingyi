import AVFoundation
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedSection: SettingsSection = .models
    @Published var enabledModelIDs: Set<String> = Set(AppSettings.defaults.enabledModelIDs)
    @Published var modelOrderIDs: [String] = AppSettings.defaults.modelOrderIDs
    @Published var readClipboardOnOpen = AppSettings.defaults.readClipboardOnOpen
    @Published var anonymousAnalyticsEnabled = AppSettings.defaults.anonymousAnalyticsEnabled
    @Published var hotkey = HotkeyConfig.default
    @Published var customModelAPIKeys: [String: String] = [:]
    @Published var customModelBaseURLs: [String: String] = [:]
    @Published var customModelProviderModelIDs: [String: String] = [:]
    @Published var customModelCredentialMessages: [String: String] = [:]
    @Published var customModelCredentialStates: [String: CustomModelCredentialState] = [:]
    @Published var historyEntries: [TranslationHistoryEntry] = []
    @Published var selectedHistoryEntryID: UUID?
    @Published private var historyCopyMessages: [String: String] = [:]

    private let settingsStore: AppSettingsStore
    private let keychainStore: KeychainStore
    private let clipboardManager: ClipboardManager
    private let historyStore: TranslationHistoryStore
    private let credentialValidator: OpenAICompatibleTranslateClient
    private let speechSynthesizer = AVSpeechSynthesizer()

    var availableModels: [TranslationModel] {
        modelOrderIDs.map { TranslationModel.model(for: $0) }
    }

    var enabledModelIDsInOrder: [String] {
        modelOrderIDs.filter { enabledModelIDs.contains($0) }
    }

    init(
        settingsStore: AppSettingsStore,
        keychainStore: KeychainStore,
        clipboardManager: ClipboardManager,
        historyStore: TranslationHistoryStore,
        credentialValidator: OpenAICompatibleTranslateClient = OpenAICompatibleTranslateClient()
    ) {
        self.settingsStore = settingsStore
        self.keychainStore = keychainStore
        self.clipboardManager = clipboardManager
        self.historyStore = historyStore
        self.credentialValidator = credentialValidator
        load()
    }

    func load() {
        let settings = settingsStore.load()
        enabledModelIDs = Set(settings.enabledModelIDs)
        modelOrderIDs = normalizedModelOrderIDs(settings.modelOrderIDs)
        readClipboardOnOpen = settings.readClipboardOnOpen
        anonymousAnalyticsEnabled = settings.anonymousAnalyticsEnabled
        hotkey = settings.hotkey
        loadCustomModelConfigs()
        reloadHistory()
    }

    func isModelEnabled(_ model: TranslationModel) -> Bool {
        enabledModelIDs.contains(model.id)
    }

    func setModel(_ model: TranslationModel, isEnabled: Bool) {
        if isEnabled {
            enabledModelIDs.insert(model.id)
        } else {
            enabledModelIDs.remove(model.id)
        }
        save()
    }

    func moveModel(sourceID: String, before destinationID: String) {
        guard
            sourceID != destinationID,
            let sourceIndex = modelOrderIDs.firstIndex(of: sourceID),
            let destinationIndex = modelOrderIDs.firstIndex(of: destinationID)
        else {
            return
        }

        let movedModelID = modelOrderIDs.remove(at: sourceIndex)
        modelOrderIDs.insert(movedModelID, at: destinationIndex)
        save()
    }

    func moveModelToEnd(_ modelID: String) {
        guard let sourceIndex = modelOrderIDs.firstIndex(of: modelID),
              sourceIndex != modelOrderIDs.count - 1 else {
            return
        }

        let movedModelID = modelOrderIDs.remove(at: sourceIndex)
        modelOrderIDs.append(movedModelID)
        save()
    }

    func save() {
        let orderedEnabledModelIDs = enabledModelIDsInOrder
        let settings = AppSettings(
            selectedModelID: orderedEnabledModelIDs.first ?? TranslationModel.defaultSelectedID,
            enabledModelIDs: orderedEnabledModelIDs,
            modelOrderIDs: modelOrderIDs,
            translationServiceBaseURL: settingsStore.load().translationServiceBaseURL,
            defaultSourceLanguage: .auto,
            defaultTargetLanguage: .auto,
            readClipboardOnOpen: readClipboardOnOpen,
            anonymousAnalyticsEnabled: anonymousAnalyticsEnabled,
            hotkey: hotkey
        )

        settingsStore.save(settings)
        NotificationCenter.default.post(name: .hotkeySettingsDidChange, object: nil)
    }

    func customModelAPIKey(for modelID: String) -> String {
        customModelAPIKeys[modelID, default: ""]
    }

    func setCustomModelAPIKey(_ value: String, for modelID: String) {
        customModelAPIKeys[modelID] = value
    }

    func customModelBaseURL(for modelID: String) -> String {
        customModelBaseURLs[modelID, default: ""]
    }

    func setCustomModelBaseURL(_ value: String, for modelID: String) {
        customModelBaseURLs[modelID] = value
    }

    func customModelProviderModelID(for modelID: String) -> String {
        customModelProviderModelIDs[modelID, default: ""]
    }

    func setCustomModelProviderModelID(_ value: String, for modelID: String) {
        customModelProviderModelIDs[modelID] = value
    }

    func customModelCredentialMessage(for modelID: String) -> String {
        customModelCredentialMessages[modelID, default: ""]
    }

    func customModelCredentialState(for modelID: String) -> CustomModelCredentialState {
        customModelCredentialStates[modelID, default: .idle]
    }

    func saveCustomModelCredentials(for modelID: String) async {
        let model = TranslationModel.model(for: modelID)
        guard modelID != TranslationModel.volcengineTranslateID else {
            customModelCredentialMessages[modelID] = "火山翻译不使用此配置"
            customModelCredentialStates[modelID] = .warning
            return
        }

        let baseURL = resolvedCustomModelBaseURL(for: model)
        let providerModelID = resolvedCustomModelProviderModelID(for: model)
        let apiKey = customModelAPIKey(for: modelID).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !baseURL.isEmpty, !providerModelID.isEmpty, !apiKey.isEmpty else {
            customModelCredentialMessages[modelID] = "请填写 API Key 后再保存验证"
            customModelCredentialStates[modelID] = .warning
            return
        }

        do {
            settingsStore.saveCustomModelConfig(
                CustomModelConfig(
                    baseURL: baseURL,
                    modelID: providerModelID
                ),
                for: modelID
            )
            try keychainStore.saveSecret(apiKey, account: KeychainStore.customModelAPIKeyAccount(for: modelID))
            customModelBaseURLs[modelID] = baseURL
            customModelProviderModelIDs[modelID] = providerModelID
        } catch {
            customModelCredentialMessages[modelID] = error.localizedDescription
            customModelCredentialStates[modelID] = .invalid
            return
        }

        customModelCredentialMessages[modelID] = "\(model.displayName) API 信息已保存，正在验证..."
        customModelCredentialStates[modelID] = .checking

        do {
            let result = try await credentialValidator.validateCredentials(
                baseURL: baseURL,
                modelID: providerModelID,
                apiKey: apiKey
            )
            switch result {
            case .credentialsValid:
                customModelCredentialMessages[modelID] = "\(model.displayName) API 信息已保存，Key 验证通过"
                customModelCredentialStates[modelID] = .valid
            case .modelAvailable:
                customModelCredentialMessages[modelID] = "\(model.displayName) API 信息已保存，模型验证通过"
                customModelCredentialStates[modelID] = .valid
            case .modelNotListed(let providerModelID):
                customModelCredentialMessages[modelID] = "已保存并验证 Key，但未在模型列表中找到 \(providerModelID)"
                customModelCredentialStates[modelID] = .warning
            }
        } catch {
            customModelCredentialMessages[modelID] = "已保存，但验证失败：\(error.localizedDescription)"
            customModelCredentialStates[modelID] = .invalid
        }
    }

    func clearCustomModelCredentials(for modelID: String) {
        let model = TranslationModel.model(for: modelID)
        do {
            try keychainStore.deleteSecret(
                account: KeychainStore.customModelAPIKeyAccount(for: modelID)
            )
            customModelAPIKeys[modelID] = ""
            customModelCredentialStates[modelID] = .idle
            customModelCredentialMessages[modelID] = "\(model.displayName) API Key 已清除"
        } catch {
            customModelCredentialMessages[modelID] = error.localizedDescription
            customModelCredentialStates[modelID] = .invalid
        }
    }

    var selectedHistoryEntry: TranslationHistoryEntry? {
        guard let selectedHistoryEntryID else {
            return historyEntries.first
        }
        return historyEntries.first { $0.id == selectedHistoryEntryID } ?? historyEntries.first
    }

    func selectHistoryEntry(_ entry: TranslationHistoryEntry) {
        selectedHistoryEntryID = entry.id
        historyCopyMessages = [:]
    }

    func deleteSelectedHistoryEntry() {
        guard let id = selectedHistoryEntry?.id else {
            return
        }
        historyStore.delete(id: id)
        reloadHistory()
    }

    func copyHistorySource(_ entry: TranslationHistoryEntry) {
        clipboardManager.copy(entry.sourceText)
        historyCopyMessages["source-\(entry.id.uuidString)"] = "已复制"
    }

    func copyHistoryResult(_ result: TranslationHistoryResult) {
        let text = result.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            historyCopyMessages[result.modelID] = "暂无可复制的译文"
            return
        }

        clipboardManager.copy(text)
        historyCopyMessages[result.modelID] = "已复制"
    }

    func speakHistorySource(_ entry: TranslationHistoryEntry) {
        speak(entry.sourceText)
    }

    func speakHistoryResult(_ result: TranslationHistoryResult) {
        speak(result.translatedText)
    }

    func historyCopyMessage(for key: String) -> String {
        historyCopyMessages[key, default: ""]
    }

    private func reloadHistory() {
        historyEntries = historyStore.load()
        if let selectedHistoryEntryID,
           historyEntries.contains(where: { $0.id == selectedHistoryEntryID }) {
            return
        }
        selectedHistoryEntryID = historyEntries.first?.id
        historyCopyMessages = [:]
    }

    private func speak(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            return
        }

        speechSynthesizer.speak(AVSpeechUtterance(string: trimmedText))
    }

    private func resolvedCustomModelBaseURL(for model: TranslationModel) -> String {
        let baseURL = customModelBaseURL(for: model.id).trimmingCharacters(in: .whitespacesAndNewlines)
        return baseURL.isEmpty ? model.defaultBaseURL ?? "" : baseURL
    }

    private func resolvedCustomModelProviderModelID(for model: TranslationModel) -> String {
        let providerModelID = customModelProviderModelID(for: model.id).trimmingCharacters(in: .whitespacesAndNewlines)
        return providerModelID.isEmpty ? model.defaultProviderModelID : providerModelID
    }

    private func normalizedModelOrderIDs(_ modelIDs: [String]) -> [String] {
        let supportedIDs = Set(TranslationModel.supported.map(\.id))
        var seen = Set<String>()
        var normalized = modelIDs.filter { modelID in
            guard supportedIDs.contains(modelID), !seen.contains(modelID) else {
                return false
            }
            seen.insert(modelID)
            return true
        }

        for modelID in TranslationModel.supported.map(\.id) where !seen.contains(modelID) {
            normalized.append(modelID)
        }

        return normalized
    }

    private func loadCustomModelConfigs() {
        for model in availableModels where model.id != TranslationModel.volcengineTranslateID {
            let config = settingsStore.loadCustomModelConfig(for: model.id)
            customModelBaseURLs[model.id] = config.baseURL
            customModelProviderModelIDs[model.id] = config.modelID

            do {
                customModelAPIKeys[model.id] = try keychainStore.loadSecret(
                    account: KeychainStore.customModelAPIKeyAccount(for: model.id)
                )
                customModelCredentialMessages[model.id] = ""
                customModelCredentialStates[model.id] = .idle
            } catch {
                customModelCredentialMessages[model.id] = error.localizedDescription
                customModelCredentialStates[model.id] = .invalid
            }
        }
    }
}

enum CustomModelCredentialState {
    case idle
    case checking
    case valid
    case warning
    case invalid
}
