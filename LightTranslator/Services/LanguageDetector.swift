import Foundation

struct LanguageDetector {
    func resolveTargetLanguage(for text: String, selectedTarget: LanguageOption) -> LanguageOption {
        if selectedTarget != .auto {
            return selectedTarget
        }

        let scalars = text.unicodeScalars
        let chineseCount = scalars.filter { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }.count
        let latinCount = scalars.filter { scalar in
            CharacterSet.letters.contains(scalar) && scalar.isASCII
        }.count

        if chineseCount > 0, chineseCount >= max(1, latinCount / 2) {
            return .english
        }

        return .simplifiedChinese
    }
}
