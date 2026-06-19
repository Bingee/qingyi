import Foundation

enum TranslationServiceError: LocalizedError {
    case noSelectedModel
    case missingProviderCredentials(String)
    case invalidServiceBaseURL
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noSelectedModel:
            return "请先在设置中选择一个翻译模型。"
        case .missingProviderCredentials(let providerName):
            return "请先在设置中填写并保存\(providerName)的 API 信息。"
        case .invalidServiceBaseURL:
            return "翻译服务地址格式不正确。"
        case .invalidResponse:
            return "翻译服务返回格式无法解析。"
        case .apiError(let message):
            return message
        }
    }
}

@MainActor
final class TranslationService {
    private let settingsStore: AppSettingsStore
    private let keychainStore: KeychainStore
    private let urlSession: URLSession
    private let openAICompatibleClient: OpenAICompatibleTranslateClient
    private let usageIdentity: AnonymousUsageIdentity

    init(
        settingsStore: AppSettingsStore,
        keychainStore: KeychainStore = KeychainStore(),
        urlSession: URLSession = .shared,
        usageIdentity: AnonymousUsageIdentity = AnonymousUsageIdentity()
    ) {
        self.settingsStore = settingsStore
        self.keychainStore = keychainStore
        self.urlSession = urlSession
        self.openAICompatibleClient = OpenAICompatibleTranslateClient(urlSession: urlSession)
        self.usageIdentity = usageIdentity
    }

    func translate(
        text: String,
        sourceLanguage: LanguageOption,
        targetLanguage: LanguageOption
    ) async throws -> [ModelTranslationResult] {
        let settings = settingsStore.load()
        let modelIDs = settings.enabledModelIDs

        guard !modelIDs.isEmpty else {
            throw TranslationServiceError.noSelectedModel
        }

        let supportedModelIDs = modelIDs.filter { modelID in
            TranslationModel.supported.contains(where: { $0.id == modelID })
        }

        let tasks = supportedModelIDs.enumerated().map { index, modelID in
            Task { @MainActor in
                    let startedAt = Date()
                    do {
                        let result = try await self.translateSingleModel(
                            modelID: modelID,
                            text: text,
                            sourceLanguage: sourceLanguage,
                            targetLanguage: targetLanguage,
                            latencyStartDate: startedAt
                        )
                        return IndexedModelTranslationResult(index: index, result: result)
                    } catch {
                        return IndexedModelTranslationResult(
                            index: index,
                            result: ModelTranslationResult(
                                modelID: modelID,
                                translatedText: "",
                                errorMessage: error.localizedDescription,
                                latencyMS: nil
                            )
                        )
                    }
                }
        }

        var orderedResults = Array<ModelTranslationResult?>(repeating: nil, count: supportedModelIDs.count)
        for task in tasks {
            let indexedResult = await task.value
            orderedResults[indexedResult.index] = indexedResult.result
        }
        let results = orderedResults.compactMap { $0 }

        guard !results.isEmpty else {
            throw TranslationServiceError.noSelectedModel
        }

        return results
    }

    private func translateSingleModel(
        modelID: String,
        text: String,
        sourceLanguage: LanguageOption,
        targetLanguage: LanguageOption,
        latencyStartDate: Date
    ) async throws -> ModelTranslationResult {
        if modelID == TranslationModel.volcengineTranslateID {
            return try await translateWithHostedVolcengine(
                modelID: modelID,
                text: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                latencyStartDate: latencyStartDate
            )
        }

        return try await translateWithCustomOpenAICompatibleModel(
            modelID: modelID,
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            latencyStartDate: latencyStartDate
        )
    }

    private func translateWithCustomOpenAICompatibleModel(
        modelID: String,
        text: String,
        sourceLanguage: LanguageOption,
        targetLanguage: LanguageOption,
        latencyStartDate: Date
    ) async throws -> ModelTranslationResult {
        let config = settingsStore.loadCustomModelConfig(for: modelID)
        let apiKey = try keychainStore
            .loadSecret(account: KeychainStore.customModelAPIKeyAccount(for: modelID))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let providerModelID = config.modelID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !apiKey.isEmpty, !baseURL.isEmpty, !providerModelID.isEmpty else {
            let name = TranslationModel.model(for: modelID).displayName
            throw TranslationServiceError.missingProviderCredentials(name)
        }

        let translatedText = try await openAICompatibleClient.translate(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            baseURL: baseURL,
            modelID: providerModelID,
            apiKey: apiKey
        )

        return ModelTranslationResult(
            modelID: modelID,
            translatedText: translatedText,
            errorMessage: nil,
            latencyMS: latencyMS(since: latencyStartDate)
        )
    }

    private func translateWithHostedVolcengine(
        modelID: String,
        text: String,
        sourceLanguage: LanguageOption,
        targetLanguage: LanguageOption,
        latencyStartDate: Date
    ) async throws -> ModelTranslationResult {
        let settings = settingsStore.load()
        guard let endpoint = makeTranslationURL(from: settings.translationServiceBaseURL) else {
            throw TranslationServiceError.invalidServiceBaseURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if settings.anonymousAnalyticsEnabled {
            applyAnonymousUsageHeaders(to: &request)
        }
        request.httpBody = try JSONEncoder().encode(
            HostedTranslateRequest(
                text: text,
                sourceLanguage: sourceLanguage.rawValue,
                targetLanguage: targetLanguage.rawValue,
                modelIds: [modelID]
            )
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationServiceError.invalidResponse
        }

        let decoded = try? JSONDecoder().decode(HostedTranslateResponse.self, from: data)
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = decoded?.message
                ?? String(data: data, encoding: .utf8)
                ?? "HTTP \(httpResponse.statusCode)"
            throw TranslationServiceError.apiError(message)
        }

        guard let result = decoded?.results.first else {
            throw TranslationServiceError.invalidResponse
        }

        return ModelTranslationResult(
            modelID: result.modelID,
            translatedText: result.text ?? "",
            errorMessage: result.error,
            latencyMS: result.latencyMS ?? latencyMS(since: latencyStartDate)
        )
    }

    private func makeTranslationURL(from baseURL: String) -> URL? {
        guard var components = URLComponents(string: baseURL) else {
            return nil
        }

        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }
        if !path.hasSuffix("/api/translate") {
            path += "/api/translate"
        }
        components.path = path
        return components.url
    }

    private func applyAnonymousUsageHeaders(to request: inout URLRequest) {
        request.setValue(usageIdentity.installID(), forHTTPHeaderField: "X-Qingyi-Install-Id")
        request.setValue(usageIdentity.appVersion, forHTTPHeaderField: "X-Qingyi-App-Version")
        request.setValue(usageIdentity.osVersion, forHTTPHeaderField: "X-Qingyi-OS-Version")
    }

    private func latencyMS(since startDate: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(startDate) * 1000))
    }
}

final class AnonymousUsageIdentity {
    private enum Keys {
        static let installID = "analytics.installID"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func installID() -> String {
        if let savedInstallID = defaults.string(forKey: Keys.installID),
           !savedInstallID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return savedInstallID
        }

        let installID = UUID().uuidString
        defaults.set(installID, forKey: Keys.installID)
        return installID
    }

    var appVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, buildVersion) {
        case let (.some(shortVersion), .some(buildVersion)) where !shortVersion.isEmpty && !buildVersion.isEmpty:
            return "\(shortVersion) (\(buildVersion))"
        case let (.some(shortVersion), _) where !shortVersion.isEmpty:
            return shortVersion
        default:
            return "unknown"
        }
    }

    var osVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }
}

private struct HostedTranslateRequest: Encodable {
    let text: String
    let sourceLanguage: String
    let targetLanguage: String
    let modelIds: [String]
}

private struct HostedTranslateResponse: Decodable {
    let results: [HostedTranslationResult]
    let message: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeIfPresent([HostedTranslationResult].self, forKey: .results) ?? []
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }

    enum CodingKeys: String, CodingKey {
        case results
        case message
    }
}

private struct HostedTranslationResult: Decodable {
    let modelID: String
    let text: String?
    let error: String?
    let latencyMS: Int?

    enum CodingKeys: String, CodingKey {
        case modelID = "modelId"
        case text
        case error
        case latencyMS = "latencyMs"
    }
}

private struct IndexedModelTranslationResult {
    let index: Int
    let result: ModelTranslationResult
}
