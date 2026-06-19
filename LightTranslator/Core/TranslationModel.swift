import Foundation

struct TranslationModel: Identifiable, Equatable, Hashable {
    static let volcengineTranslateID = "volcengine-translate"
    static let customOpenAICompatibleID = "custom-openai-compatible"

    let id: String
    let displayName: String
    let description: String
    let systemImage: String
    let assetName: String?

    var defaultBaseURL: String? {
        switch id {
        case "gpt-5.4-nano":
            return "https://api.openai.com/v1"
        case "deepseek-v4-flash":
            return "https://api.deepseek.com"
        case "gemini-3.5-flash":
            return "https://generativelanguage.googleapis.com/v1beta/openai/"
        default:
            return nil
        }
    }

    var defaultProviderModelID: String {
        id == Self.customOpenAICompatibleID ? "" : id
    }

    static let supported: [TranslationModel] = [
        TranslationModel(
            id: volcengineTranslateID,
            displayName: "火山翻译",
            description: "免费可用，适合日常快速翻译。",
            systemImage: "flame",
            assetName: "VolcengineModelIcon"
        ),
        TranslationModel(
            id: "gpt-5.4-nano",
            displayName: "OpenAI",
            description: "需自行配置 OpenAI-compatible API 信息。",
            systemImage: "sparkles",
            assetName: "GPTModelIcon"
        ),
        TranslationModel(
            id: "deepseek-v4-flash",
            displayName: "DeepSeek",
            description: "需自行配置 DeepSeek 或兼容接口 API 信息。",
            systemImage: "bolt.circle",
            assetName: "DeepSeekModelIcon"
        ),
        TranslationModel(
            id: "gemini-3.5-flash",
            displayName: "Gemini",
            description: "需自行配置兼容接口 API 信息。",
            systemImage: "diamond",
            assetName: "GeminiModelIcon"
        ),
        TranslationModel(
            id: customOpenAICompatibleID,
            displayName: "自定义",
            description: "接入其他 OpenAI-compatible 大模型。",
            systemImage: "cpu",
            assetName: "CustomModelIcon"
        )
    ]

    static let defaultSelectedID = volcengineTranslateID

    static func model(for id: String) -> TranslationModel {
        supported.first { $0.id == id } ?? TranslationModel(
            id: id,
            displayName: id,
            description: "适合通用文本翻译。",
            systemImage: "cpu",
            assetName: nil
        )
    }
}

struct ModelTranslationResult: Identifiable, Equatable {
    let modelID: String
    let translatedText: String
    let errorMessage: String?
    let latencyMS: Int?

    var id: String { modelID }

    var model: TranslationModel {
        TranslationModel.model(for: modelID)
    }

    var hasText: Bool {
        !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct TranslationHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let sourceText: String
    let sourceLanguage: LanguageOption
    let targetLanguage: LanguageOption
    let results: [TranslationHistoryResult]

    var primaryResultText: String {
        results.first { !$0.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?.translatedText ?? ""
    }
}

struct TranslationHistoryResult: Identifiable, Codable, Equatable {
    let modelID: String
    let translatedText: String
    let errorMessage: String?
    let latencyMS: Int?

    var id: String { modelID }

    var model: TranslationModel {
        TranslationModel.model(for: modelID)
    }

    var hasText: Bool {
        !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension TranslationHistoryResult {
    init(result: ModelTranslationResult) {
        modelID = result.modelID
        translatedText = result.translatedText
        errorMessage = result.errorMessage
        latencyMS = result.latencyMS
    }
}
