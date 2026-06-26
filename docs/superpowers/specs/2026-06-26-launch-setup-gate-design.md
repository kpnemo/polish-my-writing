# Launch Setup Gate — Design

**Date:** 2026-06-26
**Status:** Approved design, ready for implementation

## Overview

Polish My Writing needs two things before it can do anything useful:

1. **An API key** for at least one provider (Anthropic / OpenAI / OpenRouter).
2. **macOS Accessibility permission** (`AXIsProcessTrusted`), used to read and
   replace the selected text.

Today these are only checked **lazily**, when the user presses the polish
hotkey. A fresh install therefore looks "running" (menu-bar icon present) but
silently does nothing until the user happens to open Settings and discovers what
is missing.

This feature adds a **launch-time gate**: on every launch the app checks both
requirements and, if either is missing, automatically opens the right setup
window. Once both are satisfied it never interrupts.

## Goals

- On launch, detect missing API key and/or missing Accessibility permission.
- Auto-open the most appropriate setup surface for what is missing.
- Re-check on every launch until setup is complete; never nag once it is.
- Make the auto-open self-explanatory (a banner says what is still needed).
- Keep the decision logic pure and unit-tested in `PolishCore`.

## Non-Goals

- No change to the lazy check on the polish hotkey (it stays as a backstop).
- No new persisted state / "don't show again" preference. "Every launch until
  resolved" is intentionally stateless — the requirements *are* the state.
- No polling for Accessibility changes while running (granting it requires an
  app relaunch anyway; the onboarding window already handles that).

## Decisions (confirmed)

- **"API key for any provider"** — the user is considered set up if **any**
  provider holds a non-empty key, even one they are not currently using.
- **Accessibility-missing routing** — open the dedicated Accessibility
  onboarding window (it has the Open-Settings + Restart flow), not Settings.
- **Cadence** — re-check and auto-open on **every launch** until resolved.
- **Banner** — Settings gains a top status banner listing what is still missing.

## Architecture

Follows the project's logic/glue split: pure decision logic lives in
`PolishCore` (unit-tested); macOS I/O and window presentation live in `App/`.

### 1. `Sources/PolishCore/SetupStatus.swift` (new, pure, tested)

- `hasAnyAPIKey(in store: SecretStore) -> Bool` — true if any
  `Provider.allCases` member has a non-empty stored key.
- `struct SetupStatus { hasAPIKey, hasAccessibility }` — `Equatable`,
  `Sendable`. Exposes `isComplete`, `missingAPIKey`, `missingAccessibility`.
- `enum SetupPresentation { none, settings, accessibility, settingsWithBoth }`
  and `SetupStatus.presentation` mapping the four combinations:

  | hasAPIKey | hasAccessibility | presentation        | window opened          |
  |-----------|------------------|---------------------|------------------------|
  | true      | true             | `.none`             | nothing                |
  | false     | true             | `.settings`         | Settings (banner)      |
  | true      | false            | `.accessibility`    | Accessibility onboarding |
  | false     | false            | `.settingsWithBoth` | Settings (banner lists both) |

### 2. `App/AppState.swift` (wiring)

- `var setupStatus: SetupStatus` — builds the status from
  `hasAnyAPIKey(in: secretStore)` and `PermissionsManager.hasAccessibility()`.
- `func presentSetupIfNeeded()` — switches on `setupStatus.presentation`:
  `.settings`/`.settingsWithBoth` → `presentSettings()`; `.accessibility` →
  `requestAccessibility()`; `.none` → nothing.
- Called once from `init` after `registerHotkeys()` via
  `Task { @MainActor [weak self] in self?.presentSetupIfNeeded() }`, so it runs
  immediately after launch on the main actor.
- **Activation-policy coordination** — the `.settingsWithBoth` flow can leave the
  Settings and Accessibility windows open at once. Both window controllers expose
  `isVisible` + an `onWillClose` callback; `AppState.updateActivationPolicy()`
  (deferred so the closing window's `isVisible` has flipped) sets `.regular` while
  *any* setup window is open and `.accessory` only once they all close — so
  closing one window never orphans the other.
- **Cold-launch activation** — surfacing the window from the launch gate requires
  forced activation: at launch there is no user gesture, so the macOS 14+
  cooperative `NSApp.activate()` is ignored and the window opens *behind* the
  frontmost app. The window controllers' `show()` therefore use
  `NSApp.activate(ignoringOtherApps: true)` (matches the existing `Notifier`
  pattern). Verified by launch instrumentation: the gate ran and the window was
  `isVisible=true` but the app was not frontmost until this fix.

### 3. `App/SettingsView.swift` (banner)

- A `Section` pinned to the top of the `Form`, shown only while setup is
  incomplete. It lists each missing item:
  - missing key → "Add an API key for a provider below…"
  - missing Accessibility → row with an **Enable…** button →
    `state.requestAccessibility()`.
- Reactivity: a local `@State var setup: SetupStatus`, refreshed in `onAppear`
  and after **Save Key** / key submit, so the banner clears the instant a key is
  saved. Defaults to "complete" so the banner never flashes before `onAppear`.

## Data Flow

```
launch → AppState.init → Task @MainActor → presentSetupIfNeeded()
        → setupStatus (Keychain read + AXIsProcessTrusted)
        → presentation → presentSettings() | requestAccessibility() | nothing
```

## Error Handling

- Keychain read failures are treated as "no key" (the existing `apiKey(for:)`
  glue already swallows errors to `""`); `hasAnyAPIKey` mirrors that — a
  failed read must not crash launch.
- Presentation is idempotent: `requestAccessibility()` already guards on
  `hasAccessibility()`, and the window controllers reuse a single window.

## Testing

`Tests/PolishCoreTests/SetupStatusTests.swift`:

- `hasAnyAPIKey`: none set → false; one set → true; non-selected/first/multiple
  providers set → true.
- Error-handling paths use dedicated `SecretStore` doubles (not
  `InMemorySecretStore`, whose setter converts `""` to nil): a `FixedKeyStore`
  returning a literal `""` → false (exercises the empty-string branch), and a
  `ThrowingKeyStore` → false (locks in "a failed read is swallowed as no key").
- `SetupStatus.presentation`: all four combinations.
- `isComplete` / `missing*` flags.

App-layer wiring/UI is verified by compiling the app target (no unit tests for
`App/` glue, per existing convention). Note: the project builds in **Swift 5
language mode** (`SWIFT_VERSION 5.0`, tools-version 5.9), so the new code's actor
isolation is correct by inspection but not enforced by strict-concurrency
checking.
