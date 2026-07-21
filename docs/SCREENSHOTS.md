# Screenshoty mobilne (CI → Discord)

Generowane automatycznie na Linuxie (viewport telefonu **412×915**), bez instalacji APK na fizycznym urządzeniu.

**Ważne:** screeny idą **tylko na Discord** (i opcjonalnie jako artefakt Actions). **Nigdy** nie commituj PNG-ów / `docs/screenshots/` na GitHub — zaśmiecają historię.

## Lokalnie

```bash
mkdir -p dist/screenshots/mobile
SCREENSHOT_OUTPUT_DIR=dist/screenshots/mobile \
  flutter test test/screenshots/generate_mobile_screenshots_test.dart \
  --dart-define=SCREENSHOT_MODE=true
```

## Discord (bot)

ID serwera / kanału **nie trzymaj w repo** — tylko w env / GitHub Secrets (`~/.config/dialectium/discord.env` lokalnie).

1. [Discord Developer Portal](https://discord.com/developers/applications) → Bot → token
2. Zaproś bota (Send Messages + Attach Files)
3. Secrets / env:
   - `DISCORD_BOT_TOKEN` (albo lokalnie `DISCORD_APP_BOT_TOKEN`)
   - `DISCORD_CHANNEL_ID`
   - opcjonalnie `DISCORD_GUILD_ID`

```bash
set -a && source ~/.config/dialectium/discord.env && set +a
export DISCORD_BOT_TOKEN="${DISCORD_APP_BOT_TOKEN}"
./scripts/publish_screenshots_discord.sh dist/screenshots/mobile
unset DISCORD_APP_BOT_TOKEN DISCORD_MOD_BOT_TOKEN DISCORD_BOT_TOKEN
```

## CI

Workflow: `.github/workflows/mobile-screenshots.yml` — push na `main` (lib/assets) lub `workflow_dispatch`.

Wynik: wiadomość na Discord + artefakt Actions (`mobile-screenshots`, 14 dni). **Bez commita na main.**
