# Screenshoty mobilne (CI)

Generowane automatycznie na Linuxie (viewport telefonu **412×915**), bez instalacji APK na fizycznym urządzeniu.

## Lokalnie

```bash
mkdir -p dist/screenshots/mobile
SCREENSHOT_OUTPUT_DIR=dist/screenshots/mobile \
  flutter test test/screenshots/generate_mobile_screenshots_test.dart \
  --dart-define=SCREENSHOT_MODE=true
```

## Discord (bot)

ID serwera / kanału **nie trzymaj w repo** — tylko w env / GitHub Secrets.

1. [Discord Developer Portal](https://discord.com/developers/applications) → Bot → token
2. Zaproś bota (Send Messages + Attach Files)
3. Secrets / env:
   - `DISCORD_BOT_TOKEN`
   - `DISCORD_CHANNEL_ID`
   - opcjonalnie `DISCORD_GUILD_ID`

```bash
export DISCORD_BOT_TOKEN='…'
export DISCORD_CHANNEL_ID='…'
./scripts/publish_screenshots_discord.sh dist/screenshots/mobile
```

## CI

Workflow: `.github/workflows/mobile-screenshots.yml` — push na `main` (lib/assets) lub `workflow_dispatch`.

Artefakty: `docs/screenshots/mobile/latest/` + archiwum `vX.Y.Z/`.
