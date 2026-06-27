# 2026-06-27 — Menu-bar reliability + Settings improvements

Four changes, confirmed with the user (all "recommended" options chosen).

## 1. Bug: menu-bar icon disappears after days / sleep-wake; Settings won't open

**Root cause (systematic debugging).** The icon is a SwiftUI `MenuBarExtra`
(`App/AppMain.swift`). The status item it manages is framework-owned and is
silently dropped by macOS across sleep/wake, long uptime, and display
reconfiguration, with **no SwiftUI API to recover it**. The 1.0.1 fix removed
activation-policy toggling (one trigger) but the underlying fragility remained.
With the icon gone, the only in-app route to Settings is gone too, so the app
appears dead.

**Fix.** Replace `MenuBarExtra` with an AppKit-owned `NSStatusItem`
(`StatusItemController`) that the app controls and can recreate. Re-assert
(remove + recreate) on `NSWorkspace.didWakeNotification` and
`NSApplication.didChangeScreenParametersNotification`. Add `NSLog` diagnostics so
any recurrence is debuggable. App ownership moves to an `AppDelegate`
(`NSApplicationDelegateAdaptor`) so `AppState` is created deterministically at
`applicationDidFinishLaunching` (a `MenuBarExtra`-less SwiftUI `App` would never
initialize a `@StateObject`). The `App` body becomes `Settings { EmptyView() }`.

## 2. Test-the-key button

A dedicated **Test** button next to *Save Key* in Settings. Runs a built-in
sample with typos through the chosen provider + entered key + selected model and
shows the polished result, or the exact provider/network error. Logic lives in
`PolishCore.PolishTester` (testable; returns `PolishTestResult`). App glue calls
it with `DefaultProviderFactory` and the draft key.

## 3. Model selection under the provider (top-3 + Custom)

Move model choice out of *Advanced* to directly under the provider's key. A
`Picker` of the provider's top-3 models (recommended preselected) plus a
**Custom…** option that reveals a free-text model-ID field (safety net for any
ID, and for existing users whose saved model isn't in the list). Lists live on
`Provider.models: [ModelOption]`; `defaultModel` equals the first (recommended)
model's id.

Proposed lists (recommended ★ first):
- Anthropic: ★ Claude Haiku 4.5 (`claude-haiku-4-5`) / Sonnet 4.6 / Opus 4.8
- OpenAI: ★ `gpt-4o-mini` / `gpt-4o` / `gpt-4.1`
- OpenRouter: ★ `openai/gpt-4o-mini` / `anthropic/claude-3.5-haiku` / `google/gemini-2.5-flash`
- Gemini: ★ `gemini-2.5-flash` / `gemini-2.5-flash-lite` / `gemini-2.5-pro`

## 4. Custom polishing level

Add `PolishLevel.custom` as a 4th case (selectable in Settings and the menu).
When selected, Settings shows a text box (seeded with an example) whose text
drives the polish. Stored as `Settings.customPrompt` (backward-compatible
decode). `PromptBuilder.systemPrompt(for:customPrompt:)` uses the custom text as
the level clause when level == `.custom` and the text is non-empty; otherwise it
falls back to the Standard clause so an empty custom prompt is never sent.

## Verification
`swift test` (PolishCore logic, TDD) + `xcodebuild` (App compiles). Then a
multi-agent adversarial review (concurrency / spec / UX / Swift-correctness).
