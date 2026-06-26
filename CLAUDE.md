# Polish My Writing — Project Guide

macOS menu-bar app: select text in any app, press a global hotkey, and the
selection is polished in place (grammar/typos/wording) while preserving voice,
meaning, and original language. No backend — it calls the user's chosen LLM
provider directly with the user's own API key.

- Product/design context: `docs/superpowers/specs/2026-06-24-polish-my-writing-design.md`
- Per-feature specs live in `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.

## Architecture: the logic / glue split

Two layers, and which one code belongs in is the single most important call:

- **`Sources/PolishCore/`** — a Swift Package library (`PolishCore`, macOS 13+).
  Pure, deterministic, I/O-free decision logic. **Fully unit-tested.** Contains:
  providers (Anthropic/OpenAI/OpenRouter), `PolishService`, `PromptBuilder`,
  `Settings`/`SettingsStore`, `SecretStore` protocol + `InMemorySecretStore`,
  `SetupStatus` (launch-gate decision logic), `HotkeyConfig`, `PolishLevel`.
- **`App/`** — the macOS app target (`PolishMyWriting`, macOS 14+, SwiftUI
  `MenuBarExtra`). System I/O and UI glue only: windows, global hotkeys (Carbon),
  Accessibility (`AXIsProcessTrusted`), Keychain, launch-at-login, relaunch.
  **No unit tests** — verified by compiling.

**Rule:** put anything with a meaningful decision or invariant in `PolishCore`
behind a testable interface; keep `App/` as thin glue that supplies real-world
facts (Keychain reads, AX status) and acts on the result. When you need to test
something that touches the system, inject it (e.g. `SecretStore`) and test the
logic with the in-memory implementation.

## Build & test — two toolchains

`swift build`/`swift test` only cover `PolishCore`. The app target is built by
xcodebuild via an xcodegen-generated project. **Verify both** after a change:

```bash
# Core logic (fast): library + unit tests
swift build
swift test                       # or: swift test --filter <SuiteName>

# App target (compiles App/ glue — catches SwiftUI/AppKit errors)
xcodegen generate
xcodebuild -project PolishMyWriting.xcodeproj -scheme PolishMyWriting \
  -configuration Debug -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build
```

`xcodegen generate` rebuilds `PolishMyWriting.xcodeproj` from `project.yml` +
on-disk sources, so new files are picked up automatically — never hand-edit the
`.xcodeproj` (it is generated). New `PolishCore` sources flow in via the package
dependency; new `App/` files via the `App/` source path.

### Scripts (`scripts/`)
- `setup_local_signing.sh` — one-time: stable self-signed identity so the
  Accessibility (TCC) grant survives rebuilds.
- `build_install.sh` — build Release, install to /Applications, sign, launch.
- `make_dmg.sh` / `release.sh` — drag-to-install DMG / signed+notarized DMG.
- `uninstall.sh` — remove the app AND all local data (Keychain key, TCC grant,
  prefs) for a true first-run test.

## Conventions

- **Secrets** live only in the Keychain (`KeychainStore`, service
  `app.polishmywriting.apikeys`), keyed by `Provider.rawValue` — never in
  `Settings`/`UserDefaults`. Bundle id: `app.polishmywriting.app`.
- **Settings** persist via `SettingsStore`; `Settings.init(from:)` decodes every
  field with a default fallback, so adding a field stays backward-compatible.
- `Provider` is the single source of truth for provider metadata (display name,
  default model, API-keys URL). Iterate `Provider.allCases` for "any provider".
- Accessibility is checked lazily on the polish hotkey **and** eagerly by the
  launch setup gate (see below). Granting it needs an app relaunch — the
  `AccessibilityWindowController` onboarding window owns that Open-Settings +
  Restart flow.

## How we operate (dev workflow)

1. **Brainstorm** the feature (superpowers brainstorming) — confirm intent and
   the genuine design decisions before writing code.
2. **Spec** it to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
3. **Implement** with the logic/glue split above.
4. **Verify both toolchains** (`swift test` + app `xcodebuild`) — evidence before
   claiming done.
5. **Adversarially review** non-trivial changes with a multi-agent Workflow
   (independent concurrency / spec / UX lenses), then apply confirmed fixes.
6. **Update docs + memory** so decisions and conventions carry into future
   sessions.

## Releasing

The app is distributed as a **free, notarized Developer ID DMG** (the Mac App
Store is blocked by the sandbox — see `docs/`/memory). Hosted on GitHub Releases
(`kpnemo/polish-my-writing`, public) and the author's own website.

To ship a new version:
1. Bump `CFBundleShortVersionString` in `App/Info.plist` and `MARKETING_VERSION`
   in `project.yml` (and the build numbers).
2. Run `scripts/publish_release.sh` (needs the Developer ID cert + notarytool
   creds — pass `NOTARY_KEY`/`NOTARY_KEY_ID`/`NOTARY_ISSUER` env, or a stored
   `pmw-notary` profile). It builds → signs → notarizes → staples → publishes a
   new GitHub release with the DMG.

**NEVER delete old releases or tags.** `download_count` is per-release, so
deleting one drops its downloads from the cumulative total (the README badge
sums all releases). `publish_release.sh` never deletes and refuses to clobber an
existing tag. The stable download link always points at the newest:
`…/releases/latest/download/PolishMyWriting.dmg`.

## Features

- **Launch setup gate** — on launch, if no provider has an API key or
  Accessibility is off, auto-open the right setup window; re-checks every launch
  until both are satisfied. Logic: `Sources/PolishCore/SetupStatus.swift`
  (`SetupStatus`, `SetupPresentation`, `hasAnyAPIKey`); wiring:
  `AppState.presentSetupIfNeeded()`; banner: `SettingsView`. Spec:
  `docs/superpowers/specs/2026-06-26-launch-setup-gate-design.md`.
