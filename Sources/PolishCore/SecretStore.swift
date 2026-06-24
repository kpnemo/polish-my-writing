import Foundation

public protocol SecretStore {
    func apiKey(for provider: Provider) throws -> String?
    func setAPIKey(_ key: String?, for provider: Provider) throws
}

/// Test/double implementation. The real Keychain-backed store lives in the app target.
public final class InMemorySecretStore: SecretStore {
    private var storage: [Provider: String] = [:]

    public init() {}

    public func apiKey(for provider: Provider) throws -> String? {
        storage[provider]
    }

    public func setAPIKey(_ key: String?, for provider: Provider) throws {
        if let key, !key.isEmpty {
            storage[provider] = key
        } else {
            storage[provider] = nil
        }
    }
}
