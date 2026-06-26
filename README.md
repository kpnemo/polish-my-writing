# Polish My Writing

[![Downloads](https://img.shields.io/github/downloads/kpnemo/polish-my-writing/total?label=downloads&color=2ea44f)](https://github.com/kpnemo/polish-my-writing/releases/latest)

A tiny macOS menu-bar app that polishes your writing **in place, in any app**.
Select text, press a hotkey, and your grammar, spelling, and wording are cleaned
up — while keeping your voice, meaning, and original language. It's a polish, not
a rewrite.

- **Works everywhere** — Mail, Slack, Notes, browsers, anywhere you can select text.
- **Bring your own key** — Anthropic, OpenAI, OpenRouter, or Google Gemini. Your key, your account.
- **Private by design** — there is no backend. Your text goes straight from your
  Mac to the provider you chose. See [PRIVACY.md](PRIVACY.md).
- **Any language** — it polishes in whatever language you wrote.

## Install

1. Download **Polish My Writing.dmg** from the [latest release](../../releases/latest).
2. Open the DMG and drag **Polish My Writing** into **Applications**.
3. Launch it from Applications. It lives in the menu bar (no Dock icon).

On first launch the Settings window opens automatically and walks you through two
quick steps:

1. **Add an API key** for your provider (Anthropic / OpenAI / OpenRouter).
2. **Enable Accessibility** — macOS requires this so the app can replace your
   selected text. Turn it on in System Settings → Privacy & Security →
   Accessibility, then restart the app.

## Use it

1. Select some text in any app.
2. Press **⌥⌘P** (configurable).
3. The selection is replaced with a polished version.

Open Settings any time with **⌥⌘,** or from the menu-bar icon.

## Why isn't this on the Mac App Store?

The Mac App Store requires the App Sandbox, which forbids an app from reading and
replacing the selected text in *other* apps — that's the whole point of this one.
So, like Alfred, Raycast, TextExpander, and Grammarly's desktop app, it's
distributed directly as a notarized, Developer ID-signed app. It's free.

## Build from source

Requires Xcode, [XcodeGen](https://github.com/yonsa/XcodeGen), and macOS 14+.

```bash
xcodegen generate
xcodebuild -project PolishMyWriting.xcodeproj -scheme PolishMyWriting build
swift test            # PolishCore unit tests
```

Helper scripts live in `scripts/` (`build_install.sh`, `make_dmg.sh`,
`release.sh` for a signed + notarized DMG, `uninstall.sh`).

## License

See [LICENSE](LICENSE).
