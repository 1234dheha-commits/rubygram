# Rubygram

Personal iOS Telegram client fork, based on [Swiftgram](https://github.com/Swiftgram/Telegram-iOS) (which in turn is based on [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS)).

This is **not affiliated with Telegram FZ-LLC** and uses the open Telegram API per their developer terms.

## What's different vs Swiftgram

- Branded as "Rubygram"
- "Swiftgram Pro" settings entry is replaced by an always-visible **Developer** pane
- Developer pane includes:
  - **Code Magic** — trigger Codemagic builds (dev IPA / TestFlight) from the app
  - **App Icon** — alternate icon picker (reused from Swiftgram)
  - **Accent Color** — opens Telegram's theme settings
  - **FLEX Debug Overlay** — toggle the FLEX explorer (debug builds only)

## License

GPLv2 with the Telegram-iOS additional notes. See LICENSE in the upstream
[Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS) repository.

## Build

Built via Codemagic — see `codemagic.yaml`. Two workflows:

- `ios-release` — dev IPA for Sideloadly
- `ios-appstore` — TestFlight / App Store IPA

Triggering a build manually (replace `<TOKEN>` and `<APP_ID>` with your Codemagic credentials):

```
curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "x-auth-token: <TOKEN>" \
  "https://api.codemagic.io/builds" \
  -d '{"appId":"<APP_ID>","workflowId":"ios-release","branch":"main"}'
```

## Configuration

Build configurations live in `build-system/`:

- `rubygram-configuration.json` — App Store build
- `rubygram-dev-configuration.json` — Development build

Both reference bundle id `recode.rubygram32`.

## Credits

Original work © Telegram FZ-LLC; Swiftgram modifications © Swiftgram team.
Rubygram modifications © personal use.
