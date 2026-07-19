#!/usr/bin/env bash
# Sygnalizuje portalowi Anielki, że tata pracuje lokalnie w Cursorze.
# Użycie: portal-busy.sh start|ping|edit|stop
set -euo pipefail

MODE="${1:-ping}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/anielka-portal/data/local_busy.json"
mkdir -p "$(dirname "$OUT")"

INPUT="$(cat || true)"

export MODE OUT INPUT
python3 - <<'PY'
import json, os, time
from datetime import datetime, timezone
from pathlib import Path

mode = os.environ.get("MODE", "ping")
out = Path(os.environ["OUT"])
raw = os.environ.get("INPUT") or ""

def now():
    return datetime.now(timezone.utc).isoformat()

detail = "Tata pracuje lokalnie w Cursorze…"
path = ""
try:
    payload = json.loads(raw) if raw.strip() else {}
except json.JSONDecodeError:
    payload = {}

# Best-effort extract edited file / prompt hint from hook payload
for key in ("path", "file", "filePath", "file_path", "uri"):
    if isinstance(payload.get(key), str) and payload[key]:
        path = payload[key]
        break
if not path and isinstance(payload.get("files"), list) and payload["files"]:
    f0 = payload["files"][0]
    if isinstance(f0, str):
        path = f0
    elif isinstance(f0, dict):
        path = f0.get("path") or f0.get("file") or ""

if path:
    short = path.replace("\\", "/").split("/")[-3:]
    detail = "Tata edytuje: " + "/".join(short)

if mode == "stop":
    data = {
        "busy": False,
        "source": "local",
        "detail": "",
        "path": "",
        "updatedAt": now(),
    }
elif mode == "start":
    data = {
        "busy": True,
        "source": "local",
        "detail": "Tata zaczął lokalną sesję w Cursorze…",
        "path": "",
        "updatedAt": now(),
        "startedAt": now(),
    }
else:
    prev = {}
    if out.exists():
        try:
            prev = json.loads(out.read_text(encoding="utf-8"))
        except Exception:
            prev = {}
    data = {
        "busy": True,
        "source": "local",
        "detail": detail if mode == "edit" and path else (prev.get("detail") or detail),
        "path": path or prev.get("path") or "",
        "updatedAt": now(),
        "startedAt": prev.get("startedAt") or now(),
    }

out.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
print("{}")
PY
