import Foundation

public protocol TextCapturing {
    /// Save the user's current clipboard so it can be restored later.
    func saveClipboard()
    /// Synthesize Cmd+C and return the copied selection (nil if nothing was copied).
    func copySelection() -> String?
    /// Put `text` on the clipboard and synthesize Cmd+V to replace the selection.
    func pasteReplacement(_ text: String)
    /// Restore the clipboard saved by `saveClipboard()`.
    func restoreClipboard()
}

public protocol UserNotifying {
    func notify(_ message: String)
    func openSettings()
}

public final class PolishService {
    private let settingsProvider: () -> Settings
    private let secretStore: SecretStore
    private let capturing: TextCapturing
    private let notifier: UserNotifying
    private let factory: LLMProviderFactory
    /// Delay before restoring the clipboard after pasting, so the paste lands first.
    private let restoreDelayNanos: UInt64

    public init(
        settingsProvider: @escaping () -> Settings,
        secretStore: SecretStore,
        capturing: TextCapturing,
        notifier: UserNotifying,
        factory: LLMProviderFactory,
        restoreDelayNanos: UInt64 = 0
    ) {
        self.settingsProvider = settingsProvider
        self.secretStore = secretStore
        self.capturing = capturing
        self.notifier = notifier
        self.factory = factory
        self.restoreDelayNanos = restoreDelayNanos
    }

    public func polishSelection() async {
        let settings = settingsProvider()

        // 1. Require an API key BEFORE touching the clipboard.
        guard let apiKey = try? secretStore.apiKey(for: settings.provider),
              !apiKey.isEmpty
        else {
            notifier.openSettings()
            return
        }

        // 2. Save clipboard, then copy the selection.
        capturing.saveClipboard()
        let raw = capturing.copySelection() ?? ""
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            capturing.restoreClipboard()
            notifier.notify(PolishError.noSelection.userMessage)
            return
        }

        // 3. Call the provider.
        let provider = factory.make(settings.provider, apiKey: apiKey)
        let systemPrompt = PromptBuilder.systemPrompt(for: settings.level)
        do {
            let polished = try await provider.polish(
                text: raw, systemPrompt: systemPrompt, model: settings.model
            )
            capturing.pasteReplacement(polished)
            if restoreDelayNanos > 0 {
                try? await Task.sleep(nanoseconds: restoreDelayNanos)
            }
            capturing.restoreClipboard()
        } catch let error as PolishError {
            capturing.restoreClipboard()
            notifier.notify(error.userMessage)
        } catch {
            capturing.restoreClipboard()
            notifier.notify(PolishError.network(error.localizedDescription).userMessage)
        }
    }
}
