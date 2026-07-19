#!/usr/bin/env bash
# Start portalu Anielki (Tailscale).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export ANIELKA_PORTAL_PORT="${ANIELKA_PORTAL_PORT:-7474}"
export ANIELKA_PORTAL_PIN="${ANIELKA_PORTAL_PIN:-3141}"
export ANIELKA_PORTAL_URL="${ANIELKA_PORTAL_URL:-http://nixos.tail4caf1.ts.net:7474}"
export ANIELKA_PORTAL_IP_URL="${ANIELKA_PORTAL_IP_URL:-http://100.68.72.119:7474}"
export ANIELKA_WORKSPACE="${ANIELKA_WORKSPACE:-$ROOT}"
exec python3 "$ROOT/anielka-portal/server.py"
