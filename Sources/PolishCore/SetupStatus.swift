import Foundation

/// Whether the app has the two things it needs before it can do any work:
/// at least one provider API key, and macOS Accessibility permission.
///
/// This is pure, I/O-free decision logic so it can be unit-tested. The app layer
/// supplies the two facts (read from the Keychain and `AXIsProcessTrusted`) and
/// acts on `isComplete` / the `missing*` flags. When anything is missing the app
/// opens Settings, which surfaces both the "how to use" and "what's missing"
/// banners — so there is no per-case window routing to model here.
public struct SetupStatus: Equatable, Sendable {
    public let hasAPIKey: Bool
    public let hasAccessibility: Bool

    public init(hasAPIKey: Bool, hasAccessibility: Bool) {
        self.hasAPIKey = hasAPIKey
        self.hasAccessibility = hasAccessibility
    }

    /// Nothing is missing — the app is fully usable and must not interrupt.
    public var isComplete: Bool { hasAPIKey && hasAccessibility }

    public var missingAPIKey: Bool { !hasAPIKey }
    public var missingAccessibility: Bool { !hasAccessibility }
}

/// True when at least one provider has a non-empty stored API key.
///
/// "Any provider" is intentional: a user may hold a key for a provider they are
/// not currently using and still be considered set up. A failed Keychain read is
/// treated as "no key" so it can never crash launch.
public func hasAnyAPIKey(in store: SecretStore) -> Bool {
    Provider.allCases.contains { provider in
        let key = (try? store.apiKey(for: provider)) ?? nil
        return !(key ?? "").isEmpty
    }
}
