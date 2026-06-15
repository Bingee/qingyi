import Foundation

enum TranslationServiceError: LocalizedError {
    case noSelectedModel
    case invalidServiceBaseURL
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noSelectedModel:
            return "请先在设置中选择一个翻译模型。"
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
    private let urlSession: URLSession

    init(
        settingsStore: AppSettingsStore,
        urlSession: URLSession = .shared
    ) {
        self.settingsStore = settingsStore
        self.urlSession = urlSession
    }

    func translate(
        text: String,
        sourceLanguage: LanguageOption,
        targetLanguage: LanguageOption
    ) async throws -> [ModelTranslationResult] {
        let settings = settingsStore.load()
        let modelID = settings.selectedModelID

        guard TranslationModel.supported.contains(where: { $0.id == modelID }) else {
            throw TranslationServiceError.noSelectedModel
        }

        guard let endpoint = makeTranslationURL(from: settings.translationServiceBaseURL) else {
            throw TranslationServiceError.invalidServiceBaseURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            TranslationBatchRequest(
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

        guard (200...299).contains(httpResponse.statusCode) else {
            let decodedError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            let message = decodedError?.message
                ?? String(data: data, encoding: .utf8)
                ?? "HTTP \(httpResponse.statusCode)"
            throw TranslationServiceError.apiError(message)
        }

        let decoded = try JSONDecoder().decode(TranslationBatchResponse.self, from: data)
        let resultsByModel = Dictionary(uniqueKeysWithValues: decoded.results.map { ($0.modelId, $0) })

        return [modelID].map { modelID in
            guard let result = resultsByModel[modelID] else {
                return ModelTranslationResult(
                    modelID: modelID,
                    translatedText: "",
                    errorMessage: "服务未返回该模型的结果。",
                    latencyMS: nil
                )
            }

            return ModelTranslationResult(
                modelID: result.modelId,
                translatedText: result.text ?? "",
                errorMessage: result.error,
                latencyMS: result.latencyMs
            )
        }
    }

    private func makeTranslationURL(from baseURLString: String) -> URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var components = URLComponents(string: trimmed) else {
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
}

private struct TranslationBatchRequest: Encodable {
    let text: String
    let sourceLanguage: String
    let targetLanguage: String
    let modelIds: [String]
}

private struct TranslationBatchResponse: Decodable {
    let results: [TranslationResultDTO]
}

private struct TranslationResultDTO: Decodable {
    let modelId: String
    let text: String?
    let error: String?
    let latencyMs: Int?
}

private struct APIErrorResponse: Decodable {
    let message: String?
}
