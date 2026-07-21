#!/usr/bin/env bash
# Pomija budowę llama.cpp gdy SKIP_LLM_NATIVE=1 (screenshoty / lekkie testy UI).
set -euo pipefail
CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
PKG="$(find "$CACHE/hosted" -maxdepth 2 -type d -name 'llm_llamacpp-*' 2>/dev/null | sort -V | tail -1 || true)"
HOOK="${PKG}/hook/build.dart"
if [[ ! -f "$HOOK" ]]; then
  echo "Brak hook/build.dart — pomijam" >&2
  exit 0
fi
python3 - "$HOOK" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
marker = "SKIP_LLM_NATIVE: pomijam budowę llama.cpp"
if marker in text:
    print('OK: już zpatchowane (SKIP_LLM_NATIVE)')
    sys.exit(0)
needle = "    logger.info('Building llm_llamacpp for $targetOS-$targetArch');"
insert = """    logger.info('Building llm_llamacpp for $targetOS-$targetArch');

    // Dialectium: lekkie testy UI / screenshoty bez natywnego llama.cpp
    if (Platform.environment['SKIP_LLM_NATIVE'] == '1') {
      logger.warning('SKIP_LLM_NATIVE: pomijam budowę llama.cpp');
      return;
    }"""
if needle not in text:
    raise SystemExit(f'Nie znaleziono needle w {p}')
p.write_text(text.replace(needle, insert, 1))
print(f'Patched {p}')
PY
