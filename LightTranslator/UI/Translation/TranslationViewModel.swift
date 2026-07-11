import AVFoundation
import Foundation
@preconcurrency import Translation

struct AppleLocalTranslationRequest: Equatable {
    let id: UUID
    let text: String
    let sourceLanguageIdentifier: String?
    let targetLanguageIdentifier: String?
}

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
    @Published private(set) var appleTranslationRequest: AppleLocalTranslationRequest?

    private let settingsStore: AppSettingsStore
    private let clipboardManager: ClipboardManager
    private let languageDetector: LanguageDetector
    private let translationService: TranslationService
    private let historyStore: TranslationHistoryStore
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var translationTask: Task<Void, Never>?
    private var activeTranslationID: UUID?
    private var pendingModelIDs = Set<String>()
    private var activeRequestText = ""
    private var activeTargetLanguage: LanguageOption = .simplifiedChinese
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

    /// A global shortcut always starts a new translation session. In particular,
    /// it must not expose the previous input or translated text.
    func prepareForHotkeyOpen() {
        cancelActiveTranslation()
        sourceText = ""
        translationResults = []
        copyMessages = [:]
        status = .editing
        refreshEnabledModels()
    }

    func translate() {
        let requestText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestText.isEmpty else {
            status = .failed("请输入要翻译的文本。")
            return
        }

        cancelActiveTranslation()
        let translationID = UUID()
        activeTranslationID = translationID
        let source = languageDetector.resolveSourceLanguage(
            for: requestText,
            selectedSource: sourceLanguage
        )
        let target = languageDetector.resolveTargetLanguage(
            for: requestText,
            selectedTarget: targetLanguage
        )
        refreshEnabledModels()
        resolvedTargetLanguage = target
        status = .translating
        translationResults = []
        copyMessages = [:]
        activeRequestText = requestText
        activeTargetLanguage = target
        pendingModelIDs = Set(enabledModels.map(\.id))

        guard !pendingModelIDs.isEmpty else {
            status = .failed("请先在设置中选择一个翻译模型。")
            return
        }

        if enabledModels.contains(where: { $0.id == TranslationModel.appleLocalTranslationID }) {
            requestAppleLocalTranslation(
                text: requestText,
                sourceLanguage: source,
                targetLanguage: target,
                translationID: translationID
            )
        }

        let hasCloudModels = enabledModels.contains {
            $0.id != TranslationModel.appleLocalTranslationID
        }
        guard hasCloudModels else {
            return
        }

        translationTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let results = try await translationService.translate(
                    text: requestText,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: target
                )
                guard !Task.isCancelled, activeTranslationID == translationID else {
                    return
                }

                completeTranslationResults(results, translationID: translationID)
            } catch {
                guard !Task.isCancelled, activeTranslationID == translationID else {
                    return
                }

                let failures = enabledModels
                    .filter { $0.id != TranslationModel.appleLocalTranslationID }
                    .map {
                        ModelTranslationResult(
                            modelID: $0.id,
                            translatedText: "",
                            errorMessage: error.localizedDescription,
                            latencyMS: nil
                        )
                    }
                completeTranslationResults(failures, translationID: translationID)
            }
        }
    }

    @available(macOS 15.0, *)
    func translateWithAppleLocal(
        _ session: TranslationSession,
        request: AppleLocalTranslationRequest
    ) async {
        guard activeTranslationID == request.id,
              pendingModelIDs.contains(TranslationModel.appleLocalTranslationID)
        else {
            return
        }

        do {
            // This asks macOS to prepare (or download) the selected language pair.
            // Without it, a fresh machine can silently have no on-device model ready.
            try await session.prepareTranslation()
            let response = try await session.translate(request.text)
            guard activeTranslationID == request.id else {
                return
            }

            completeTranslationResults(
                [
                    ModelTranslationResult(
                        modelID: TranslationModel.appleLocalTranslationID,
                        translatedText: response.targetText,
                        errorMessage: nil,
                        latencyMS: nil
                    )
                ],
                translationID: request.id
            )
        } catch {
            guard activeTranslationID == request.id else {
                return
            }

            completeTranslationResults(
                [
                    ModelTranslationResult(
                        modelID: TranslationModel.appleLocalTranslationID,
                        translatedText: "",
                        errorMessage: appleLocalTranslationErrorMessage(error),
                        latencyMS: nil
                    )
                ],
                translationID: request.id
            )
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

    private func requestAppleLocalTranslation(
        text: String,
        sourceLanguage: LanguageOption,
        targetLanguage: LanguageOption,
        translationID: UUID
    ) {
        guard #available(macOS 15.0, *) else {
            completeTranslationResults(
                [
                    ModelTranslationResult(
                        modelID: TranslationModel.appleLocalTranslationID,
                        translatedText: "",
                        errorMessage: "苹果本地翻译需要 macOS 15 或更高版本。",
                        latencyMS: nil
                    )
                ],
                translationID: translationID
            )
            return
        }

        appleTranslationRequest = AppleLocalTranslationRequest(
            id: translationID,
            text: text,
            sourceLanguageIdentifier: sourceLanguage.appleLocalTranslationLanguageIdentifier,
            targetLanguageIdentifier: targetLanguage.appleLocalTranslationLanguageIdentifier
        )
    }

    @available(macOS 15.0, *)
    private func appleLocalTranslationErrorMessage(_ error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("Unable to Translate") {
            return "苹果本地翻译暂不可用。请在系统设置中下载英语与简体中文语言包后重试。"
        }
        return message
    }

    private func completeTranslationResults(
        _ newResults: [ModelTranslationResult],
        translationID: UUID
    ) {
        guard activeTranslationID == translationID else {
            return
        }

        var resultsByModelID = Dictionary(
            uniqueKeysWithValues: translationResults.map { ($0.modelID, $0) }
        )
        for result in newResults {
            resultsByModelID[result.modelID] = result
            pendingModelIDs.remove(result.modelID)
        }
        translationResults = enabledModels.compactMap { resultsByModelID[$0.id] }

        guard pendingModelIDs.isEmpty else {
            return
        }

        saveHistory(
            sourceText: activeRequestText,
            targetLanguage: activeTargetLanguage,
            results: translationResults
        )
        status = .success
        translationTask = nil
    }

    private func cancelActiveTranslation() {
        translationTask?.cancel()
        translationTask = nil
        activeTranslationID = nil
        pendingModelIDs = []

        appleTranslationRequest = nil
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
