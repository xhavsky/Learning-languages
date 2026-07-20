#!/usr/bin/env bash
# iOS CI: llm_llamacpp nie ma prebuilt ios-arm64 — pomijamy native assets (chat iOS = fallback skrypt).
set -euo pipefail
CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
PKG="$(find "$CACHE/hosted" -maxdepth 2 -type d -name 'llm_llamacpp-*' 2>/dev/null | sort -V | tail -1 || true)"
HOOK="${PKG}/hook/build.dart"
if [[ ! -f "$HOOK" ]]; then
  echo "Brak hook/build.dart — pomijam" >&2
  exit 0
fi
if grep -q 'SKIP_LLM_NATIVE' "$HOOK"; then
  echo "OK: hook już ma SKIP_LLM_NATIVE"
  exit 0
fi
python3 - "$HOOK" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
needle = "    logger.info('Building llm_llamacpp for $targetOS-$targetArch');"
insert = """    logger.info('Building llm_llamacpp for $targetOS-$targetArch');

    if (Platform.environment['SKIP_LLM_NATIVE'] == '1' && targetOS == OS.iOS) {
      logger.warning('SKIP_LLM_NATIVE=1 — pomijam llama.cpp na iOS (CI / unsigned build)');
      return;
    }"""
if needle not in text:
    if 'SKIP_LLM_NATIVE' in text:
        print('already patched')
        sys.exit(0)
    raise SystemExit(f'Nie znaleziono needle w {p}')
p.write_text(text.replace(needle, insert, 1))
print(f'Patched {p}')
PY
