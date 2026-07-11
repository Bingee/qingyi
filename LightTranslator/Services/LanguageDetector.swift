import Foundation

struct LanguageDetector {
    func resolveSourceLanguage(for text: String, selectedSource: LanguageOption) -> LanguageOption {
        if selectedSource != .auto {
            return selectedSource
        }

        let chineseCount = text.unicodeScalars.filter { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }.count

        // The on-device Translation session is more reliable with an explicit
        // source language than with automatic detection in its configuration.
        return chineseCount > 0 ? .simplifiedChinese : .english
    }

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
