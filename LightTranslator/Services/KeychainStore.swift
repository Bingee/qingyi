import Foundation
import Security

enum KeychainError: LocalizedError {
    case unexpectedData
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedData:
            return "Keychain 返回了无法解析的数据。"
        case .unhandledStatus(let status):
            return "Keychain 操作失败，状态码：\(status)"
        }
    }
}

final class KeychainStore {
    static let volcengineAccessKeyAccount = "provider.volcengine.accessKeyID"
    static let volcengineSecretKeyAccount = "provider.volcengine.secretAccessKey"

    static func customModelAPIKeyAccount(for modelID: String) -> String {
        "provider.custom.\(modelID).apiKey"
    }

    private let service = "com.local.light-translator.provider-key"
    private let legacyAccount = "default"

    func saveAPIKey(_ apiKey: String) throws {
        try saveSecret(apiKey, account: legacyAccount)
    }

    func loadAPIKey() throws -> String {
        try loadSecret(account: legacyAccount)
    }

    func saveSecret(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }

        if status == errSecItemNotFound {
            var createQuery = query
            createQuery[kSecValueData as String] = data
            let createStatus = SecItemAdd(createQuery as CFDictionary, nil)
            guard createStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(createStatus)
            }
            return
        }

        throw KeychainError.unhandledStatus(status)
    }

    func loadSecret(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return ""
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }

        guard
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.unexpectedData
        }

        return value
    }

    func deleteSecret(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}
