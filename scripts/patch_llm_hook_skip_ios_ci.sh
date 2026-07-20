#!/usr/bin/env bash
# iOS: brak prebuilt llama.framework w pub.dev — pomijamy native assets (Bielik na iOS = fallback).
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
# Usuń stary patch jeśli był
import re
text = re.sub(
    r"\n    if \(Platform\.environment\['SKIP_LLM_NATIVE'\][\s\S]*?return;\n    \}\n",
    "\n",
    text,
    count=1,
)
needle = "    logger.info('Building llm_llamacpp for $targetOS-$targetArch');"
insert = """    logger.info('Building llm_llamacpp for $targetOS-$targetArch');

    // Trener: na iOS brak gotowego llama.framework w paczce pub.dev
    if (targetOS == OS.iOS) {
      logger.warning('iOS: pomijam budowę llama.cpp (chat użyje fallbacku)');
      return;
    }"""
if 'iOS: pomijam budowę llama.cpp' in text:
    print('OK: już zpatchowane')
    sys.exit(0)
if needle not in text:
    raise SystemExit(f'Nie znaleziono needle w {p}')
p.write_text(text.replace(needle, insert, 1))
print(f'Patched {p}')
PY
