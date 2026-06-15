import Foundation

enum LanguageOption: String, CaseIterable, Identifiable, Codable {
    case auto
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:
            return "自动"
        case .simplifiedChinese:
            return "简体中文"
        case .english:
            return "英语"
        }
    }

    var promptName: String {
        switch self {
        case .auto:
            return "Auto"
        case .simplifiedChinese:
            return "Simplified Chinese"
        case .english:
            return "English"
        }
    }
}
