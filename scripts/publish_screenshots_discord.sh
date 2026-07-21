#!/usr/bin/env bash
# Publikuje PNG z folderu na Discord (Bot API).
# Wymaga: DISCORD_BOT_TOKEN, DISCORD_CHANNEL_ID
# Opcjonalnie: DISCORD_GUILD_ID (tylko log)
set -euo pipefail

DIR="${1:-dist/screenshots/mobile}"
CHANNEL_ID="${DISCORD_CHANNEL_ID:-}"
GUILD_ID="${DISCORD_GUILD_ID:-}"
VERSION="${SCREENSHOT_VERSION:-}"
SHA="${GITHUB_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"

if [[ -z "${DISCORD_BOT_TOKEN:-}" ]]; then
  echo "DISCORD_BOT_TOKEN nie ustawiony — pomijam Discord." >&2
  exit 0
fi

if [[ -z "$CHANNEL_ID" ]]; then
  echo "DISCORD_CHANNEL_ID nie ustawiony — pomijam Discord." >&2
  exit 0
fi

if [[ ! -d "$DIR" ]]; then
  echo "Brak katalogu: $DIR" >&2
  exit 1
fi

mapfile -t FILES < <(find "$DIR" -maxdepth 1 -type f -name '*.png' | sort)
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Brak plików PNG w $DIR" >&2
  exit 1
fi

CONTENT="**Dialectium** mobile screenshots"
if [[ -n "$VERSION" ]]; then
  CONTENT+=" · \`$VERSION\`"
fi
CONTENT+=$'\n'"SHA: \`$SHA\`"
if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
  CONTENT+=$'\n'"Repo: ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/tree/main/docs/screenshots/mobile/latest"
fi

ARGS=(
  -sS -X POST
  -H "Authorization: Bot ${DISCORD_BOT_TOKEN}"
  -F "payload_json={\"content\":$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$CONTENT")}"
)

i=0
for f in "${FILES[@]}"; do
  ARGS+=(-F "files[$i]=@${f}")
  i=$((i + 1))
  if [[ $i -ge 10 ]]; then
    break
  fi
done

echo "Wysyłam ${#FILES[@]} plików na Discord…"
HTTP=$(curl "${ARGS[@]}" \
  "https://discord.com/api/v10/channels/${CHANNEL_ID}/messages" \
  -w "%{http_code}" -o /tmp/discord-screenshot-response.json)
echo "HTTP $HTTP"
# Nie wypisuj pełnej odpowiedzi (może zawierać ID)
python3 -c 'import json; d=json.load(open("/tmp/discord-screenshot-response.json")); print("ok" if d.get("id") else d.get("message", d))'
echo
if [[ "$HTTP" != "200" ]]; then
  exit 1
fi
echo "OK — wiadomość na Discord."
