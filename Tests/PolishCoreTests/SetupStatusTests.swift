import XCTest
@testable import PolishCore

final class SetupStatusTests: XCTestCase {
    // MARK: hasAnyAPIKey

    func testHasAnyAPIKeyFalseWhenNoneSet() {
        let store = InMemorySecretStore()
        XCTAssertFalse(hasAnyAPIKey(in: store))
    }

    func testHasAnyAPIKeyTrueWithOneKey() throws {
        let store = InMemorySecretStore()
        try store.setAPIKey("sk-test", for: .openai)
        XCTAssertTrue(hasAnyAPIKey(in: store))
    }

    func testHasAnyAPIKeyTrueForNonSelectedProvider() throws {
        // A key for any provider counts, not just the one currently selected.
        let store = InMemorySecretStore()
        try store.setAPIKey("key", for: .openrouter)
        XCTAssertTrue(hasAnyAPIKey(in: store))
    }

    func testHasAnyAPIKeyIgnoresEmptyString() throws {
        let store = InMemorySecretStore()
        try store.setAPIKey("", for: .anthropic)
        XCTAssertFalse(hasAnyAPIKey(in: store))
    }

    func testHasAnyAPIKeyTrueForFirstProvider() throws {
        // Guards the "scans all providers" contract from the front of the loop.
        let store = InMemorySecretStore()
        try store.setAPIKey("k", for: Provider.allCases.first!)
        XCTAssertTrue(hasAnyAPIKey(in: store))
    }

    func testHasAnyAPIKeyTrueForMultipleProviders() throws {
        let store = InMemorySecretStore()
        try store.setAPIKey("a", for: .anthropic)
        try store.setAPIKey("b", for: .openai)
        XCTAssertTrue(hasAnyAPIKey(in: store))
    }

    // A store that hands back a literal empty string exercises the empty-string
    // branch in hasAnyAPIKey — InMemorySecretStore can't, because its setter maps
    // "" to nil (stores nothing).
    func testHasAnyAPIKeyFalseForLiteralEmptyString() {
        XCTAssertFalse(hasAnyAPIKey(in: FixedKeyStore(value: "")))
    }

    func testHasAnyAPIKeyTrueForLiteralKey() {
        XCTAssertTrue(hasAnyAPIKey(in: FixedKeyStore(value: "sk-live")))
    }

    // A failed Keychain read must be swallowed as "no key", never propagated —
    // it cannot be allowed to crash launch.
    func testHasAnyAPIKeyFalseWhenStoreThrows() {
        XCTAssertFalse(hasAnyAPIKey(in: ThrowingKeyStore()))
    }

    // MARK: isComplete / missing flags

    func testIsComplete() {
        XCTAssertTrue(SetupStatus(hasAPIKey: true, hasAccessibility: true).isComplete)
        XCTAssertFalse(SetupStatus(hasAPIKey: false, hasAccessibility: true).isComplete)
        XCTAssertFalse(SetupStatus(hasAPIKey: true, hasAccessibility: false).isComplete)
        XCTAssertFalse(SetupStatus(hasAPIKey: false, hasAccessibility: false).isComplete)
    }

    func testMissingFlags() {
        let status = SetupStatus(hasAPIKey: false, hasAccessibility: false)
        XCTAssertTrue(status.missingAPIKey)
        XCTAssertTrue(status.missingAccessibility)
    }
}

// MARK: - Test doubles

/// Returns the same fixed value for every provider — lets a test feed a literal
/// "" (which `InMemorySecretStore` would otherwise convert to nil).
private struct FixedKeyStore: SecretStore {
    let value: String?
    func apiKey(for provider: Provider) throws -> String? { value }
    func setAPIKey(_ key: String?, for provider: Provider) throws {}
}

/// Always throws on read — models a failed Keychain lookup.
private struct ThrowingKeyStore: SecretStore {
    func apiKey(for provider: Provider) throws -> String? { throw PolishError.network("boom") }
    func setAPIKey(_ key: String?, for provider: Provider) throws {}
}
