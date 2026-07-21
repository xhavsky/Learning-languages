#!/bin/sh
# webview_cef GPU patch — POSIX sh (avoid #!/usr/bin/env bash when system bash missing)
# Odpalaj po `flutter pub get`, przed `flutter build linux`.
set -eu
TARGET="${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev/webview_cef-0.5.1/common/webview_plugin.cc"
if [ ! -f "$TARGET" ]; then
  echo "Brak $TARGET — najpierw flutter pub get" >&2
  exit 1
fi
# getenv() requires cstdlib
if ! grep -q '#include <cstdlib>' "$TARGET"; then
  python3 - "$TARGET" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
t = p.read_text()
needle = '#include <math.h>'
if '#include <cstdlib>' not in t and needle in t:
    p.write_text(t.replace(needle, '#include <cstdlib>\n' + needle, 1))
    print(f"Added #include <cstdlib> → {p}")
PY
fi
if grep -q 'dialectium-cef' "$TARGET"; then
  echo "OK: webview_cef już z GPU + cache path"
  exit 0
fi
python3 - "$TARGET" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
old = """\tvoid startCEF()
\t{
\t\tCefSettings cefs;
\t\tcefs.windowless_rendering_enabled = true;
\t\tcefs.no_sandbox = true;
\t\tif(!userAgent.empty()){
\t\t\tCefString(&cefs.user_agent_product) = userAgent;
\t\t}"""
new = """\tvoid startCEF()
\t{
\t\tCefSettings cefs;
\t\tcefs.windowless_rendering_enabled = true;
\t\tcefs.no_sandbox = true;
\t\t// Dialectium: model-viewer needs WebGL
\t\tif (app) {
\t\t\tapp->SetEnableGPU(true);
\t\t}
\t\t{
\t\t\tconst char* home = getenv("HOME");
\t\t\tstd::string cache = home && home[0]
\t\t\t\t? (std::string(home) + "/.cache/dialectium-cef")
\t\t\t\t: "/tmp/dialectium-cef";
\t\t\tCefString(&cefs.root_cache_path) = cache;
\t\t\tCefString(&cefs.cache_path) = cache;
\t\t}
\t\tif(!userAgent.empty()){
\t\t\tCefString(&cefs.user_agent_product) = userAgent;
\t\t}"""
if old not in text:
    if "SetEnableGPU(true)" in text:
        print("OK: already patched")
        sys.exit(0)
    raise SystemExit("Nie znaleziono bloku startCEF do patcha")
p.write_text(text.replace(old, new, 1))
print(f"Patched GPU+cache → {p}")
PY
