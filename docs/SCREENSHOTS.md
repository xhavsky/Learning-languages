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

- **Guild:** `1529057108207730698`
- **Kanał:** `1529061120483266580`

1. [Discord Developer Portal](https://discord.com/developers/applications) → New Application → Bot → Reset Token
2. OAuth2 → URL Generator: scopes `bot`, permissions **Send Messages** + **Attach Files**
3. Zaproś bota na serwer
4. GitHub Secrets (repo): `DISCORD_BOT_TOKEN`
5. Opcjonalnie lokalnie:

```bash
export DISCORD_BOT_TOKEN='…'
export DISCORD_CHANNEL_ID=1529061120483266580
./scripts/publish_screenshots_discord.sh dist/screenshots/mobile
```

## CI

Workflow: `.github/workflows/mobile-screenshots.yml` — push na `main` (lib/assets) lub `workflow_dispatch`.

Artefakty: `docs/screenshots/mobile/latest/` + archiwum `vX.Y.Z/`.
