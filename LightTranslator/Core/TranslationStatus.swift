import Foundation

enum TranslationStatus: Equatable {
    case idle
    case editing
    case translating
    case success
    case failed(String)

    var isTranslating: Bool {
        if case .translating = self {
            return true
        }
        return false
    }
}
