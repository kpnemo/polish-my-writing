/// Result of a one-shot "does this key work?" check.
public enum PolishTestResult: Equatable, Sendable {
    /// The provider returned polished text for the sample.
    case success(polished: String)
    /// A user-facing error message (bad key, network, decoding, …).
    case failure(message: String)
}

/// Runs a fixed sample with deliberate mistakes through a provider so the user
/// can verify their key/model work and see the exact error if they don't. Pure
/// decision logic — the network is injected via `LLMProviderFactory`.
public struct PolishTester {
    /// Sample text with spelling, grammar, and punctuation mistakes.
    public static let defaultSample =
        "Helo, I has recieved you're mesage and wil rsepond tommorow—thx alot."

    private let factory: LLMProviderFactory

    public init(factory: LLMProviderFactory) {
        self.factory = factory
    }

    public func test(
        provider: Provider,
        apiKey: String,
        model: String,
        sample: String = PolishTester.defaultSample
    ) async -> PolishTestResult {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            return .failure(message: "Enter an API key first, then press Test.")
        }
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            return .failure(message: "Choose or enter a model first, then press Test.")
        }

        let llm = factory.make(provider, apiKey: key)
        let systemPrompt = PromptBuilder.systemPrompt(for: .standard)
        do {
            let polished = try await llm.polish(
                text: sample, systemPrompt: systemPrompt, model: trimmedModel
            )
            let trimmed = polished.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return .failure(message: PolishError.emptyResponse.userMessage)
            }
            return .success(polished: trimmed)
        } catch let error as PolishError {
            return .failure(message: error.userMessage)
        } catch {
            return .failure(message: PolishError.network(error.localizedDescription).userMessage)
        }
    }
}
