#!/usr/bin/env python3
"""Render orbit frames of a GLB via Playwright Chromium + model-viewer (WebKitGTK nie umie WebGL)."""
from __future__ import annotations

import argparse
import http.server
import socketserver
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models3d" / "turntable"


HTML = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<script type="module" src="https://unpkg.com/@google/model-viewer/dist/model-viewer.min.js"></script>
<style>
  html,body{{margin:0;height:100%;background:#1a1a22;overflow:hidden}}
  model-viewer{{width:100%;height:100%;--poster-color:transparent}}
</style>
</head>
<body>
<model-viewer id="mv" src="/model.glb"
  camera-controls disable-pan
  camera-orbit="{orbit}"
  camera-target="0m 0.45m 0m"
  field-of-view="30deg"
  environment-image="neutral"
  exposure="1.1"
  shadow-intensity="0.6"
  interaction-prompt="none">
</model-viewer>
</body>
</html>
"""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--glb", required=True, type=Path)
    ap.add_argument("--id", required=True, help="mascot_dog / mascot_cat")
    ap.add_argument("--frames", type=int, default=24)
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--port", type=int, default=8767)
    args = ap.parse_args()

    glb = args.glb.resolve()
    assert glb.is_file(), glb
    out_dir = OUT / args.id
    out_dir.mkdir(parents=True, exist_ok=True)

    class Handler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *_a):  # noqa: N802
            return

        def do_GET(self):  # noqa: N802
            if self.path.startswith("/model.glb"):
                data = glb.read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", "model/gltf-binary")
                self.send_header("Content-Length", str(len(data)))
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(data)
                return
            if self.path.startswith("/frame"):
                # /frame?orbit=...
                from urllib.parse import parse_qs, urlparse

                q = parse_qs(urlparse(self.path).query)
                orbit = q.get("orbit", ["0deg 75deg 105%"])[0]
                body = HTML.format(orbit=orbit).encode()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            self.send_error(404)

    httpd = socketserver.TCPServer(("127.0.0.1", args.port), Handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()

    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": args.size, "height": args.size})
        for i in range(args.frames):
            deg = int(360 * i / args.frames)
            orbit = f"{deg}deg 75deg 105%"
            url = f"http://127.0.0.1:{args.port}/frame?orbit={orbit.replace(' ', '%20')}"
            page.goto(url, wait_until="networkidle")
            page.wait_for_timeout(1200)
            dest = out_dir / f"{i:02d}.png"
            page.screenshot(path=str(dest), omit_background=False)
            print(f"OK {dest} orbit={orbit}")
        # poster = frame 0
        poster = ROOT / "assets" / "models3d" / f"{args.id}_poster.png"
        poster.write_bytes((out_dir / "00.png").read_bytes())
        print(f"poster → {poster}")
        browser.close()
    httpd.shutdown()


if __name__ == "__main__":
    main()
