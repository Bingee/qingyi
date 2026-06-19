import Foundation

@MainActor
final class OpenAICompatibleTranslateClient {
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func validateCredentials(
        baseURL: String,
        modelID: String,
        apiKey: String
    ) async throws -> ProviderCredentialValidationResult {
        guard let endpoint = makeModelsURL(from: baseURL) else {
            throw TranslationServiceError.invalidServiceBaseURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationServiceError.invalidResponse
        }

        let decodedError = try? JSONDecoder().decode(OpenAICompatibleErrorResponse.self, from: data)
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = decodedError?.error.message
                ?? String(data: data, encoding: .utf8)
                ?? "HTTP \(httpResponse.statusCode)"
            throw TranslationServiceError.apiError(message)
        }

        let decodedModels = try? JSONDecoder().decode(OpenAICompatibleModelsResponse.self, from: data)
        let modelIDs = Set(decodedModels?.data.map(\.id) ?? [])
        if modelIDs.isEmpty {
            return .credentialsValid
        }

        if modelIDs.contains(modelID) {
            return .modelAvailable
        }

        return .modelNotListed(modelID)
    }

    func translate(
        text: String,
        sourceLanguage: LanguageOption,
        targetLanguage: LanguageOption,
        baseURL: String,
        modelID: String,
        apiKey: String
    ) async throws -> String {
        guard let endpoint = makeChatCompletionsURL(from: baseURL) else {
            throw TranslationServiceError.invalidServiceBaseURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            OpenAICompatibleRequest(
                model: modelID,
                stream: false,
                temperature: 0.2,
                messages: [
                    OpenAIMessage(
                        role: "system",
                        content: "You are a professional translation engine. Only return the translated text. Do not explain, quote, or add notes."
                    ),
                    OpenAIMessage(
                        role: "user",
                        content: makePrompt(
                            text: text,
                            sourceLanguage: sourceLanguage,
                            targetLanguage: targetLanguage
                        )
                    )
                ]
            )
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationServiceError.invalidResponse
        }

        let decoded = try? JSONDecoder().decode(OpenAICompatibleResponse.self, from: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = decoded?.error?.message
                ?? String(data: data, encoding: .utf8)
                ?? "HTTP \(httpResponse.statusCode)"
            throw TranslationServiceError.apiError(message)
        }

        guard let text = decoded?.choices.first?.message.content
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else {
            throw TranslationServiceError.invalidResponse
        }

        return text
    }

    private func makeChatCompletionsURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var components = URLComponents(string: trimmed) else {
            return nil
        }

        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }

        if path.hasSuffix("/chat/completions") {
            components.path = path
            return components.url
        }

        if path.isEmpty {
            path = components.host == "api.deepseek.com"
                ? "/chat/completions"
                : "/v1/chat/completions"
        } else {
            path += "/chat/completions"
        }

        components.path = path
        return components.url
    }

    private func makeModelsURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var components = URLComponents(string: trimmed) else {
            return nil
        }

        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }

        if path.hasSuffix("/chat/completions") {
            path.removeLast("/chat/completions".count)
        }

        if path.hasSuffix("/models") {
            components.path = path
            return components.url
        }

        if path.isEmpty {
            path = components.host == "api.deepseek.com"
                ? "/models"
                : "/v1/models"
        } else {
            path += "/models"
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

enum ProviderCredentialValidationResult: Equatable {
    case credentialsValid
    case modelAvailable
    case modelNotListed(String)
}

private struct OpenAICompatibleRequest: Encodable {
    let model: String
    let stream: Bool
    let temperature: Double
    let messages: [OpenAIMessage]
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAICompatibleResponse: Decodable {
    let choices: [OpenAIChoice]
    let error: OpenAIError?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        choices = try container.decodeIfPresent([OpenAIChoice].self, forKey: .choices) ?? []
        error = try container.decodeIfPresent(OpenAIError.self, forKey: .error)
    }

    enum CodingKeys: String, CodingKey {
        case choices
        case error
    }
}

private struct OpenAICompatibleModelsResponse: Decodable {
    let data: [OpenAICompatibleModel]
}

private struct OpenAICompatibleModel: Decodable {
    let id: String
}

private struct OpenAICompatibleErrorResponse: Decodable {
    let error: OpenAIError
}

private struct OpenAIChoice: Decodable {
    let message: OpenAIMessage
}

private struct OpenAIError: Decodable {
    let message: String
}
