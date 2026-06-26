# Privacy Policy — Polish My Writing

_Last updated: 2026-06-26_

Polish My Writing is designed to keep your data in your hands. **There is no
backend server operated by this app**, and it collects no analytics or telemetry.

## What leaves your Mac, and where it goes

When you polish a selection, the app sends **only that selected text** — together
with a fixed instruction prompt — directly over HTTPS to the **LLM provider you
chose** (Anthropic, OpenAI, OpenRouter, or Google Gemini), authenticated with **your own API
key**. The polished result comes back and replaces your selection.

- The request goes from your Mac straight to your provider. It does **not** pass
  through any server controlled by the app's author.
- Your text is therefore handled under **your provider's** privacy and data-use
  terms (e.g. Anthropic, OpenAI, OpenRouter, or Google Gemini). Review theirs to understand how
  they treat API inputs.
- Nothing is sent until you trigger a polish on a specific selection.

## What stays on your Mac

- **Your API key** is stored in the macOS **Keychain**, protected by your login
  and the app's code signature. It is never written to preferences, logs, or
  disk in clear text, and never sent anywhere except to your chosen provider as
  the request's authorization.
- **Your settings** (provider, model, hotkeys, level) are stored locally.
- The app keeps **no history** of the text you polish.

## Permissions the app requests

- **Accessibility** — required by macOS so the app can copy your selection and
  paste the polished result back into the app you're using. It is used solely for
  that text replacement.

## Contact

Questions about privacy: open an issue on the project's repository.
