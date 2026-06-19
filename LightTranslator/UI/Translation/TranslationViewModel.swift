import AVFoundation
import Foundation

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var sourceText = ""
    @Published var translationResults: [ModelTranslationResult] = []
    @Published var sourceLanguage: LanguageOption
    @Published var targetLanguage: LanguageOption
    @Published var resolvedTargetLanguage: LanguageOption = .simplifiedChinese
    @Published var selectedModel = TranslationModel.model(for: TranslationModel.defaultSelectedID)
    @Published var enabledModels: [TranslationModel] = [TranslationModel.model(for: TranslationModel.defaultSelectedID)]
    @Published var status: TranslationStatus = .idle
    @Published var isPinned = false
    @Published private var copyMessages: [String: String] = [:]

    private let settingsStore: AppSettingsStore
    private let clipboardManager: ClipboardManager
    private let languageDetector: LanguageDetector
    private let translationService: TranslationService
    private let historyStore: TranslationHistoryStore
    private let speechSynthesizer = AVSpeechSynthesizer()

    init(
        settingsStore: AppSettingsStore,
        clipboardManager: ClipboardManager,
        languageDetector: LanguageDetector,
        translationService: TranslationService,
        historyStore: TranslationHistoryStore
    ) {
        self.settingsStore = settingsStore
        self.clipboardManager = clipboardManager
        self.languageDetector = languageDetector
        self.translationService = translationService
        self.historyStore = historyStore

        let settings = settingsStore.load()
        sourceLanguage = settings.defaultSourceLanguage
        targetLanguage = settings.defaultTargetLanguage
        refreshEnabledModels(settings: settings)
    }

    func prepareForOpen() {
        copyMessages = [:]
        status = .editing
        refreshEnabledModels()

        let readClipboard = settingsStore.load().readClipboardOnOpen
        guard readClipboard else {
            return
        }

        let clipboardText = clipboardManager.readText().trimmingCharacters(in: .whitespacesAndNewlines)
        if !clipboardText.isEmpty {
            sourceText = clipboardText
            translationResults = []
        }
    }

    func translate() {
        guard !status.isTranslating else {
            return
        }

        let requestText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestText.isEmpty else {
            status = .failed("请输入要翻译的文本。")
            return
        }

        let target = languageDetector.resolveTargetLanguage(
            for: requestText,
            selectedTarget: targetLanguage
        )
        refreshEnabledModels()
        resolvedTargetLanguage = target
        status = .translating
        translationResults = []
        copyMessages = [:]

        Task {
            do {
                let results = try await translationService.translate(
                    text: requestText,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: target
                )
                translationResults = results
                saveHistory(
                    sourceText: requestText,
                    targetLanguage: target,
                    results: results
                )
                status = .success
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    private func refreshEnabledModels(settings: AppSettings? = nil) {
        let currentSettings = settings ?? settingsStore.load()
        let models = currentSettings.enabledModelIDs.map { TranslationModel.model(for: $0) }
        enabledModels = models.isEmpty ? [] : models
        selectedModel = enabledModels.first ?? TranslationModel.model(for: TranslationModel.defaultSelectedID)
    }

    func swapLanguages() {
        let currentSource = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = currentSource
    }

    func markEditing() {
        guard !status.isTranslating else {
            return
        }

        status = .editing
        copyMessages = [:]
    }

    func collapseResult() {
        guard !status.isTranslating else {
            return
        }

        status = .editing
        copyMessages = [:]
    }

    func copyMessage(for modelID: String) -> String {
        copyMessages[modelID, default: ""]
    }

    func copyResult(modelID: String) {
        let result = translationResults
            .first { $0.modelID == modelID }?
            .translatedText
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !result.isEmpty else {
            copyMessages[modelID] = "暂无可复制的译文"
            return
        }

        clipboardManager.copy(result)
        copyMessages[modelID] = "已复制"
    }

    func speakResult(modelID: String) {
        let result = translationResults
            .first { $0.modelID == modelID }?
            .translatedText
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !result.isEmpty else {
            return
        }

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            return
        }

        speechSynthesizer.speak(AVSpeechUtterance(string: result))
    }

    func openHistorySettings() {
        NotificationCenter.default.post(name: .openHistorySettings, object: nil)
    }

    func togglePinned() {
        isPinned.toggle()
    }

    private func saveHistory(
        sourceText: String,
        targetLanguage: LanguageOption,
        results: [ModelTranslationResult]
    ) {
        let historyResults = results
            .filter { $0.hasText || $0.errorMessage != nil }
            .map(TranslationHistoryResult.init(result:))

        guard historyResults.contains(where: \.hasText) else {
            return
        }

        historyStore.add(
            TranslationHistoryEntry(
                id: UUID(),
                createdAt: Date(),
                sourceText: sourceText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                results: historyResults
            )
        )
    }
}
