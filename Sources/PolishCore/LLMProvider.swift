import Foundation

/// The networking seam. Real code uses URLSession; tests inject a fake.
public typealias HTTPTransport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

public func liveTransport(_ request: URLRequest) async throws -> (Data, URLResponse) {
    try await URLSession.shared.data(for: request)
}

public enum PolishError: Error, Equatable {
    case missingAPIKey
    case noSelection
    case http(status: Int, message: String)
    case emptyResponse
    case decoding
    case network(String)

    public var userMessage: String {
        switch self {
        case .missingAPIKey:
            return "No API key set. Open Settings to add one."
        case .noSelection:
            return "No text selected."
        case let .http(status, message):
            return "Provider error \(status): \(message)"
        case .emptyResponse:
            return "The model returned an empty response."
        case .decoding:
            return "Could not read the model's response."
        case let .network(message):
            return "Network error: \(message)"
        }
    }
}

public protocol LLMProvider {
    /// Returns the polished text, or throws a `PolishError`.
    func polish(text: String, systemPrompt: String, model: String) async throws -> String
}

/// Shared helper: validate the HTTP response and return the body, or throw a PolishError.
func validateHTTP(_ data: Data, _ response: URLResponse) throws -> Data {
    guard let http = response as? HTTPURLResponse else {
        throw PolishError.network("No HTTP response")
    }
    guard (200..<300).contains(http.statusCode) else {
        let body = String(data: data, encoding: .utf8) ?? ""
        throw PolishError.http(status: http.statusCode, message: body)
    }
    return data
}
