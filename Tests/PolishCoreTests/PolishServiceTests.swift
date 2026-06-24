import XCTest
@testable import PolishCore

private final class FakeCapturing: TextCapturing {
    var selectionToReturn: String?
    private(set) var events: [String] = []
    private(set) var pasted: String?

    func saveClipboard() { events.append("save") }
    func copySelection() -> String? { events.append("copy"); return selectionToReturn }
    func pasteReplacement(_ text: String) { events.append("paste"); pasted = text }
    func restoreClipboard() { events.append("restore") }
}

private final class FakeNotifier: UserNotifying {
    private(set) var messages: [String] = []
    private(set) var openedSettings = false
    func notify(_ message: String) { messages.append(message) }
    func openSettings() { openedSettings = true }
}

private struct StubProvider: LLMProvider {
    let result: Result<String, PolishError>
    func polish(text: String, systemPrompt: String, model: String) async throws -> String {
        try result.get()
    }
}

private struct StubFactory: LLMProviderFactory {
    let provider: LLMProvider
    func make(_ provider: Provider, apiKey: String) -> LLMProvider { self.provider }
}

final class PolishServiceTests: XCTestCase {
    private func makeService(
        settings: Settings = .default,
        apiKey: String? = "sk-key",
        capturing: FakeCapturing,
        notifier: FakeNotifier,
        providerResult: Result<String, PolishError>
    ) -> PolishService {
        let secrets = InMemorySecretStore()
        if let apiKey { try? secrets.setAPIKey(apiKey, for: settings.provider) }
        let factory = StubFactory(provider: StubProvider(result: providerResult))
        return PolishService(
            settingsProvider: { settings },
            secretStore: secrets,
            capturing: capturing,
            notifier: notifier,
            factory: factory
        )
    }

    func test_noAPIKey_opensSettings_andDoesNotTouchClipboard() async {
        let cap = FakeCapturing()
        let note = FakeNotifier()
        let service = makeService(apiKey: nil, capturing: cap, notifier: note, providerResult: .success("x"))
        await service.polishSelection()
        XCTAssertTrue(note.openedSettings)
        XCTAssertEqual(cap.events, []) // never touched the clipboard
    }

    func test_noSelection_restoresClipboard_andNotifies() async {
        let cap = FakeCapturing()
        cap.selectionToReturn = "   " // whitespace only
        let note = FakeNotifier()
        let service = makeService(capturing: cap, notifier: note, providerResult: .success("x"))
        await service.polishSelection()
        XCTAssertEqual(cap.events, ["save", "copy", "restore"])
        XCTAssertNil(cap.pasted)
        XCTAssertEqual(note.messages, [PolishError.noSelection.userMessage])
    }

    func test_success_pastesPolished_thenRestoresClipboard() async {
        let cap = FakeCapturing()
        cap.selectionToReturn = "polsh this"
        let note = FakeNotifier()
        let service = makeService(capturing: cap, notifier: note, providerResult: .success("polish this"))
        await service.polishSelection()
        XCTAssertEqual(cap.events, ["save", "copy", "paste", "restore"])
        XCTAssertEqual(cap.pasted, "polish this")
        XCTAssertTrue(note.messages.isEmpty)
    }

    func test_providerError_restoresClipboard_andNotifies_withoutPasting() async {
        let cap = FakeCapturing()
        cap.selectionToReturn = "polsh this"
        let note = FakeNotifier()
        let service = makeService(
            capturing: cap, notifier: note,
            providerResult: .failure(.http(status: 401, message: "bad key"))
        )
        await service.polishSelection()
        XCTAssertEqual(cap.events, ["save", "copy", "restore"])
        XCTAssertNil(cap.pasted)
        XCTAssertEqual(note.messages, [PolishError.http(status: 401, message: "bad key").userMessage])
    }
}
