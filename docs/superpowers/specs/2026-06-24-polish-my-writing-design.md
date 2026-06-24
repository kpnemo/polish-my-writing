# Polish My Writing — MVP Design

**Date:** 2026-06-24
**Status:** Approved design, ready for implementation planning

## Overview

**Polish My Writing** is a macOS menu-bar app. The user selects text in any
application, presses a global hotkey, and the selected text is polished in
place — typos, grammar, punctuation, and wording — while preserving the
writer's voice, structure, meaning, and **original language** (any language is
supported). It is a polish, not a rewrite.

There is no backend. The app calls the user's chosen LLM provider directly with
the user's own API key. The system prompt lives locally in the app.

## Goals

- Seamless "select → hotkey → polished in place" experience in any app.
- Bring-your-own-key: Anthropic, OpenAI, or OpenRouter.
- Conservative, voice-preserving polish across any language.
- Very simple settings.
- Ship as a notarized Developer ID `.dmg`.

## Non-Goals (MVP)

- No backend / hosted service.
- No Mac App Store build (deferred; would likely require a reduced
  clipboard-only mode due to sandbox limits).
- No remote system-prompt or model-config updates (a server for this may come
  later).
- No live model-list fetching; no model dropdown.

## Tech & Distribution

- **Native Swift.** SwiftUI for the settings window; AppKit for the menu-bar
  item, global hotkey, and Accessibility/clipboard work.
- **Distribution:** notarized **Developer ID `.dmg`**, Developer ID-signed with
  hardened runtime. App Store deferred.
- **Permissions:** requests the macOS **Accessibility** permission on first use
  (required to post synthetic copy/paste key events to other apps).

Native Swift is chosen over Electron/Tauri because every core capability
(global hotkeys, Accessibility, Keychain, launch-at-login) is first-class in
the native stack and awkward elsewhere.

## The Replace-in-Place Mechanism (core)

Rather than relying on each app exposing its selection through the Accessibility
text API — which is inconsistent across native, Electron, and Chrome-based apps
— the app uses the universally compatible **clipboard round-trip**:

1. Hotkey pressed → **save** the user's current clipboard contents.
2. Synthesize **⌘C** → read the selection from the clipboard.
3. If empty → notify "No text selected," restore the clipboard, abort.
4. Show in-progress feedback (menu-bar icon animates).
5. Call the LLM with the system prompt + chosen polish level + the text.
6. On success → put the polished text on the clipboard, synthesize **⌘V** to
   replace the selection.
7. **Restore** the user's original clipboard once the paste has settled.
8. Native **⌘Z** in the target app undoes the change — the safety net.

## Components

- `MenuBarController` — `NSStatusItem`; quick-switch the polish level, open
  Settings, quit.
- `HotkeyManager` — global hotkey registration (default **⌥⌘P**, configurable).
- `TextCaptureService` — clipboard save / ⌘C / ⌘V / restore via `CGEvent` and
  `NSPasteboard`.
- `PolishService` — orchestrates capture → prompt → provider → replace.
- `PromptBuilder` — builds the local system prompt with a level-specific clause.
- `LLMProvider` protocol with `AnthropicProvider`, `OpenAIProvider`,
  `OpenRouterProvider` conforming implementations.
- `SettingsStore` — non-secret preferences in `UserDefaults`.
- `KeychainStore` — API keys, stored only in the Keychain (never in prefs).
- `PermissionsManager` — check/request Accessibility permission.
- `LaunchAtLogin` — wraps `SMAppService`.
- `SettingsView` — SwiftUI settings window.

## Settings (kept minimal)

- Provider picker (Anthropic / OpenAI / OpenRouter) + API key field.
- Default polish level (Light / Standard / Thorough).
- Hotkey recorder (default **⌥⌘P**).
- Show menu-bar icon (toggle).
- Launch at login (toggle).
- Advanced (collapsed): editable model field, pre-filled with a smart default
  per provider.

### Model selection

The user picks a provider and pastes a key. The app uses a sensible hardcoded
default model per provider. The model field is pre-filled but editable for
power users. No live model-list fetching in the MVP.

## Polish Levels

All levels are conservative and preserve the writer's voice, meaning,
structure, and original language. None is a full rewrite.

- **Light** — spelling, typos, punctuation only.
- **Standard** — the above + grammar and minor word-choice fixes.
- **Thorough** — the above + clarity and flow improvements.

## The Prompt (local)

A single local system prompt with a level-specific clause injected. Rules:

- Preserve the writer's voice, meaning, structure, and **input language**
  (detect and keep whatever language the text is in).
- Only correct/improve according to the selected level.
- **Output only the polished text** — no commentary, no explanations, no
  markdown code fences.

## Error Handling

Never fail silently; always restore the clipboard on any error path.

- No API key configured → open Settings and prompt the user.
- No text selected → notify the user.
- Network / API / rate-limit error → notify the user with the reason.

## Testing

- **Unit tests:** `PromptBuilder` (correct clause per level, language-preserving
  rules present), the three providers (mocked networking — request shape and
  response parsing), `SettingsStore`, `KeychainStore`.
- **Manual / integration:** `TextCaptureService` and `HotkeyManager`. Synthetic
  key events and global hotkeys against live apps cannot be meaningfully
  unit-tested and are verified by hand across a representative set of apps
  (native, Electron, browser).

## Open Questions / Future

- Optional server to push system-prompt and model-config updates.
- Possible reduced Mac App Store build (clipboard-only mode).
- Optional preview/diff mode before replacing.
