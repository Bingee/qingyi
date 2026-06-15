import Foundation

enum TranslationServiceError: LocalizedError {
    case missingBaseURL
    case missingAPIKey
    case missingModel
    case invalidBaseURL
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "请先在设置中填写 API Base URL。"
        case .missingAPIKey:
            return "请先在设置中填写 API Key。"
        case .missingModel:
            return "请先在设置中填写 Model Name。"
        case .invalidBaseURL:
            return "API Base URL 格式不正确。"
        case .invalidResponse:
            return "模型返回格式无法解析。"
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

    init(
        settingsStore: AppSettingsStore,
        keychainStore: KeychainStore,
        urlSession: URLSession = .shared
    ) {
        self.settingsStore = settingsStore
        self.keychainStore = keychainStore
        self.urlSession = urlSession
    }

    func translate(
        text: String,
        sourceLanguage: LanguageOption,
        targetLanguage: LanguageOption
    ) async throws -> String {
        let settings = settingsStore.load()
        let apiKey = try keychainStore.loadAPIKey().trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURLString = settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelName = settings.modelName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !baseURLString.isEmpty else { throw TranslationServiceError.missingBaseURL }
        guard !apiKey.isEmpty else { throw TranslationServiceError.missingAPIKey }
        guard !modelName.isEmpty else { throw TranslationServiceError.missingModel }
        guard let endpoint = makeChatCompletionsURL(from: baseURLString) else {
            throw TranslationServiceError.invalidBaseURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatCompletionRequest(
                model: modelName,
                messages: [
                    .init(
                        role: "system",
                        content: "You are a professional translation engine. Only return the translated text. Do not explain, quote, or add notes."
                    ),
                    .init(
                        role: "user",
                        content: makePrompt(
                            text: text,
                            sourceLanguage: sourceLanguage,
                            targetLanguage: targetLanguage
                        )
                    )
                ],
                temperature: 0.2
            )
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw TranslationServiceError.apiError(errorBody)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw TranslationServiceError.invalidResponse
        }

        return content
    }

    private func makeChatCompletionsURL(from baseURLString: String) -> URL? {
        guard var components = URLComponents(string: baseURLString) else {
            return nil
        }

        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }

        if path.hasSuffix("/v1") {
            path += "/chat/completions"
        } else if path.hasSuffix("/v1/chat/completions") {
            // Keep complete compatible endpoints working.
        } else {
            path += "/v1/chat/completions"
        }

        components.path = path
        return components.url
    }

    private func makePrompt(
        text: String,
        sourceLanguage: LanguageOption,
        targetLanguage: LanguageOption
    ) -> String {
        """
        Translate the following text into \(targetLanguage.promptName).
        Source language: \(sourceLanguage.promptName).

        Requirements:
        - Preserve meaning, tone, punctuation, and formatting.
        - Return only the translated text.

        Text:
        \(text)
        """
    }
}

private struct ChatCompletionRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}
