import Foundation
import Security
import PolishCore

/// Keychain-backed SecretStore. One generic-password item per provider.
public final class KeychainStore: SecretStore {
    private let service = "app.polishmywriting.apikeys"

    public init() {}

    public func apiKey(for provider: Provider) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw PolishError.network("Keychain read failed (\(status))")
        }
        return String(data: data, encoding: .utf8)
    }

    public func setAPIKey(_ key: String?, for provider: Provider) throws {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
        // Always delete first, then add if a non-empty key is provided.
        SecItemDelete(base as CFDictionary)
        guard let key, !key.isEmpty else { return }

        var add = base
        add[kSecValueData as String] = Data(key.utf8)
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PolishError.network("Keychain write failed (\(status))")
        }
    }
}
