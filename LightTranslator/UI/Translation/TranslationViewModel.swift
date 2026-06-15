import AVFoundation
import Foundation

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var sourceText = ""
    @Published var translatedText = ""
    @Published var sourceLanguage: LanguageOption
    @Published var targetLanguage: LanguageOption
    @Published var resolvedTargetLanguage: LanguageOption = .simplifiedChinese
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
    }

    func prepareForOpen() {
        copyMessage = ""
        status = .editing

        let readClipboard = settingsStore.load().readClipboardOnOpen
        guard readClipboard else {
            return
        }

        let clipboardText = clipboardManager.readText().trimmingCharacters(in: .whitespacesAndNewlines)
        if !clipboardText.isEmpty {
            sourceText = clipboardText
            translatedText = ""
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
        resolvedTargetLanguage = target
        status = .translating
        translatedText = ""
        copyMessage = ""

        Task {
            do {
                let result = try await translationService.translate(
                    text: requestText,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: target
                )
                translatedText = result
                status = .success
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
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

    func copyResult() {
        let result = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else {
            copyMessage = "暂无可复制的译文"
            return
        }

        clipboardManager.copy(result)
        copyMessage = "已复制"
    }

    func speakResult() {
        let result = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
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
