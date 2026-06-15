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
    @Published var status: TranslationStatus = .idle
    @Published var copyMessage = ""

    private let settingsStore: AppSettingsStore
    private let clipboardManager: ClipboardManager
    private let languageDetector: LanguageDetector
    private let translationService: TranslationService
    private let speechSynthesizer = AVSpeechSynthesizer()

    init(
        settingsStore: AppSettingsStore,
        clipboardManager: ClipboardManager,
        languageDetector: LanguageDetector,
        translationService: TranslationService
    ) {
        self.settingsStore = settingsStore
        self.clipboardManager = clipboardManager
        self.languageDetector = languageDetector
        self.translationService = translationService

        let settings = settingsStore.load()
        sourceLanguage = settings.defaultSourceLanguage
        targetLanguage = settings.defaultTargetLanguage
        selectedModel = TranslationModel.model(for: settings.selectedModelID)
    }

    func prepareForOpen() {
        copyMessage = ""
        status = .editing
        refreshSelectedModel()

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
        refreshSelectedModel()
        resolvedTargetLanguage = target
        status = .translating
        translationResults = []
        copyMessage = ""

        Task {
            do {
                let results = try await translationService.translate(
                    text: requestText,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: target
                )
                translationResults = results
                status = .success
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    private func refreshSelectedModel() {
        selectedModel = TranslationModel.model(for: settingsStore.load().selectedModelID)
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
        copyMessage = ""
    }

    func collapseResult() {
        guard !status.isTranslating else {
            return
        }

        status = .editing
        copyMessage = ""
    }

    func copyResult(modelID: String) {
        let result = translationResults
            .first { $0.modelID == modelID }?
            .translatedText
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !result.isEmpty else {
            copyMessage = "暂无可复制的译文"
            return
        }

        clipboardManager.copy(result)
        copyMessage = "已复制"
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
}
