import XCTest
@testable import PolishCore

final class SecretStoreTests: XCTestCase {
    func test_setAndGet_perProvider() throws {
        let store = InMemorySecretStore()
        try store.setAPIKey("sk-anthropic", for: .anthropic)
        try store.setAPIKey("sk-openai", for: .openai)

        XCTAssertEqual(try store.apiKey(for: .anthropic), "sk-anthropic")
        XCTAssertEqual(try store.apiKey(for: .openai), "sk-openai")
        XCTAssertNil(try store.apiKey(for: .openrouter))
    }

    func test_settingNil_removesKey() throws {
        let store = InMemorySecretStore()
        try store.setAPIKey("sk-x", for: .anthropic)
        try store.setAPIKey(nil, for: .anthropic)
        XCTAssertNil(try store.apiKey(for: .anthropic))
    }
}
