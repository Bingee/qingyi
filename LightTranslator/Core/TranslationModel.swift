import Foundation

struct TranslationModel: Identifiable, Equatable, Hashable {
    let id: String
    let displayName: String
    let description: String
    let systemImage: String
    let assetName: String?

    static let supported: [TranslationModel] = [
        TranslationModel(
            id: "gpt-5.4-nano",
            displayName: "GPT",
            description: "适合正式、长段落和语气要求较高的翻译。",
            systemImage: "sparkles",
            assetName: "GPTModelIcon"
        ),
        TranslationModel(
            id: "deepseek-v4-flash",
            displayName: "DeepSeek-V4",
            description: "适合技术文档、代码说明和结构化内容翻译。",
            systemImage: "bolt.circle",
            assetName: "DeepSeekModelIcon"
        ),
        TranslationModel(
            id: "gemini-3.5-flash",
            displayName: "Gemini-3.5",
            description: "适合日常短句、网页内容和快速理解场景。",
            systemImage: "diamond",
            assetName: "GeminiModelIcon"
        )
    ]

    static let defaultSelectedID = supported[0].id

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
