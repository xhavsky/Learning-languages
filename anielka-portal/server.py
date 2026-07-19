#!/usr/bin/env python3
"""Portal WWW dla Anielki — wiadomości → Cursor Agent (projekt Trener Językowy).

Dostęp przez Tailscale. Domyślnie: http://nixos.tail4caf1.ts.net:7474
PIN: ANIELKA_PORTAL_PIN (domyślnie 3141).
"""
from __future__ import annotations

import json
import os
import queue
import shutil
import subprocess
import threading
import time
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
STATIC = ROOT / "static"
DATA = Path(os.environ.get("ANIELKA_PORTAL_DATA", str(ROOT / "data")))
HISTORY = DATA / "chat.json"
META = DATA / "meta.json"

HOST = os.environ.get("ANIELKA_PORTAL_HOST", "0.0.0.0")
PORT = int(os.environ.get("ANIELKA_PORTAL_PORT", "7474"))
PIN = os.environ.get("ANIELKA_PORTAL_PIN", "3141")
TAILSCALE_URL = os.environ.get(
    "ANIELKA_PORTAL_URL",
    "http://nixos.tail4caf1.ts.net:7474",
)
TAILSCALE_IP_URL = os.environ.get(
    "ANIELKA_PORTAL_IP_URL",
    "http://100.68.72.119:7474",
)

CURSOR_BIN = os.environ.get("CURSOR_BIN", shutil.which("cursor") or "cursor")
WORKSPACE = os.environ.get("ANIELKA_WORKSPACE", str(REPO))

_lock = threading.Lock()
_jobs: queue.Queue[str] = queue.Queue()
_busy = False


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _load_chat() -> list[dict]:
    if not HISTORY.exists():
        return []
    try:
        return json.loads(HISTORY.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []


def _save_chat(messages: list[dict]) -> None:
    DATA.mkdir(parents=True, exist_ok=True)
    HISTORY.write_text(
        json.dumps(messages, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def _append(role: str, text: str, **extra) -> dict:
    msg = {
        "id": str(uuid.uuid4()),
        "role": role,
        "text": text,
        "ts": _now(),
        **extra,
    }
    with _lock:
        chat = _load_chat()
        chat.append(msg)
        # keep last 200
        chat = chat[-200:]
        _save_chat(chat)
    return msg


def _write_meta() -> None:
    DATA.mkdir(parents=True, exist_ok=True)
    META.write_text(
        json.dumps(
            {
                "url": TAILSCALE_URL,
                "urlIp": TAILSCALE_IP_URL,
                "port": PORT,
                "pinHint": "PIN w aplikacji / u taty",
                "workspace": WORKSPACE,
                "updatedAt": _now(),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    # Also expose for Flutter app (documents-readable copy in repo assets seed)
    pub = REPO / "assets" / "data" / "portal.json"
    try:
        pub.parent.mkdir(parents=True, exist_ok=True)
        pub.write_text(
            json.dumps(
                {
                    "url": TAILSCALE_URL,
                    "urlIp": TAILSCALE_IP_URL,
                    "pin": PIN,
                    "note": "Tylko Tailscale · tymczasowy portal dla Anielki",
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
    except OSError:
        pass


SYSTEM_PREFIX = """Jesteś asystentem projektu „Trener Językowy” (Flutter) dla Anielki i taty.
WSPÓLNY katalog (shared): {workspace}
NIE edytuj worktree WIP taty (~/Dokumenty/Projekty/Learning-languages-wip).
Pracuj tylko w shared. Po większych zmianach możesz zaproponować commit na main.
Release/paczki Anielka odpala z portalu WWW (przyciski), nie buduj ręcznie ZIP chyba że prosi.
Odpowiadaj po polsku, krótko i jasno.
Wiadomość od Anielki:
"""


def _run_agent(user_text: str) -> str:
    prompt = SYSTEM_PREFIX.format(workspace=WORKSPACE) + user_text.strip()
    cmd = [
        CURSOR_BIN,
        "agent",
        "-p",
        "--force",
        "--output-format",
        "text",
        prompt,
    ]
    env = os.environ.copy()
    # Prefer working directory of the project
    try:
        proc = subprocess.run(
            cmd,
            cwd=WORKSPACE,
            capture_output=True,
            text=True,
            timeout=900,
            env=env,
        )
    except subprocess.TimeoutExpired:
        return "⏰ Agent pracował zbyt długo (timeout 15 min). Spróbuj krótszą prośbę."
    except FileNotFoundError:
        return "Nie znaleziono `cursor` na komputerze taty. Tata musi mieć Cursor CLI."

    out = (proc.stdout or "").strip()
    err = (proc.stderr or "").strip()
    if proc.returncode != 0 and not out:
        return f"Coś poszło nie tak (kod {proc.returncode}).\n{err[-2000:]}"
    if not out:
        return err[-2000:] or "(pusta odpowiedź)"
    return out


def _worker() -> None:
    global _busy
    while True:
        msg_id = _jobs.get()
        with _lock:
            chat = _load_chat()
            user = next((m for m in chat if m["id"] == msg_id), None)
        if not user:
            _jobs.task_done()
            continue
        _busy = True
        _append("system", "🤖 Myślę i pracuję nad projektem… czekaj chwilę.", status="working")
        try:
            answer = _run_agent(user["text"])
            _append("assistant", answer, replyTo=msg_id)
        except Exception as e:  # noqa: BLE001
            _append("assistant", f"Błąd: {e}", replyTo=msg_id, status="error")
        finally:
            _busy = False
            _jobs.task_done()


def _check_pin(handler: BaseHTTPRequestHandler) -> bool:
    pin = handler.headers.get("X-Portal-Pin") or ""
    if not pin:
        qs = parse_qs(urlparse(handler.path).query)
        pin = (qs.get("pin") or [""])[0]
    return pin == PIN


class Handler(BaseHTTPRequestHandler):
    server_version = "AnielkaPortal/0.1"

    def log_message(self, fmt: str, *args) -> None:
        print(f"[portal] {self.address_string()} {fmt % args}", flush=True)

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Portal-Pin")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")

    def _json(self, code: int, payload: dict | list) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self._cors()
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _bytes(self, code: int, data: bytes, ctype: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self._cors()
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path in ("/", "/index.html"):
            html = (STATIC / "index.html").read_bytes()
            return self._bytes(200, html, "text/html; charset=utf-8")
        if path == "/api/health":
            return self._json(
                200,
                {
                    "ok": True,
                    "busy": _busy,
                    "url": TAILSCALE_URL,
                    "urlIp": TAILSCALE_IP_URL,
                },
            )
        if path == "/api/info":
            return self._json(
                200,
                {
                    "url": TAILSCALE_URL,
                    "urlIp": TAILSCALE_IP_URL,
                    "name": "Portal Anielki",
                    "project": "Trener Językowy",
                },
            )
        if path == "/api/messages":
            if not _check_pin(self):
                return self._json(401, {"error": "Zły PIN. Poproś tatę."})
            with _lock:
                chat = _load_chat()
            return self._json(200, {"messages": chat, "busy": _busy})
        if path == "/api/status":
            if not _check_pin(self):
                return self._json(401, {"error": "Zły PIN. Poproś tatę."})
            return self._json(200, _workspace_status())
        if path.startswith("/static/"):
            rel = path.removeprefix("/static/")
            f = STATIC / rel
            if f.is_file():
                ctype = "text/css" if f.suffix == ".css" else "application/octet-stream"
                return self._bytes(200, f.read_bytes(), ctype)
        return self._json(404, {"error": "nie ma takiej strony"})

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        try:
            data = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            return self._json(400, {"error": "zły JSON"})

        if path == "/api/chat":
            if not _check_pin(self) and data.get("pin") != PIN:
                return self._json(401, {"error": "Zły PIN. Poproś tatę o PIN."})
            text = (data.get("text") or "").strip()
            if not text:
                return self._json(400, {"error": "Wpisz wiadomość"})
            if len(text) > 8000:
                return self._json(400, {"error": "Za długa wiadomość"})
            if _busy:
                return self._json(
                    409,
                    {"error": "Agent jeszcze pracuje. Poczekaj na odpowiedź."},
                )
            msg = _append("user", text)
            _jobs.put(msg["id"])
            return self._json(202, {"ok": True, "message": msg, "busy": True})

        if path == "/api/clear":
            if not _check_pin(self) and data.get("pin") != PIN:
                return self._json(401, {"error": "Zły PIN"})
            with _lock:
                _save_chat([])
            return self._json(200, {"ok": True})

        if path == "/api/github-publish":
            if not _check_pin(self) and data.get("pin") != PIN:
                return self._json(401, {"error": "Zły PIN"})
            user = (data.get("username") or "").strip()
            token = (data.get("token") or "").strip()
            repo = (data.get("repo") or "Learning-languages").strip() or "Learning-languages"
            if not user or not token:
                return self._json(
                    400,
                    {
                        "error": "Potrzebuję nazwy użytkownika GitHub i tokenu.",
                        "help": (
                            "1) Wejdź na https://github.com/settings/tokens\n"
                            "2) Generate new token (classic)\n"
                            "3) Zaznacz uprawnienie: repo\n"
                            "4) Skopiuj token i wklej tutaj razem z nazwą konta"
                        ),
                    },
                )
            result = _github_publish(user, token, repo)
            return self._json(200 if result.get("ok") else 500, result)

        if path == "/api/release":
            if not _check_pin(self) and data.get("pin") != PIN:
                return self._json(401, {"error": "Zły PIN"})
            kind = (data.get("kind") or "both").strip().lower()
            if kind not in ("windows", "apk", "both"):
                return self._json(400, {"error": "kind: windows | apk | both"})
            result = _trigger_release(kind)
            code = 200 if result.get("ok") else 500
            # Log for Anielka in chat
            if result.get("ok"):
                _append(
                    "system",
                    "📦 Startuję budowanie paczek ("
                    + kind
                    + "). Za kilka minut będą na GitHub Releases.\n"
                    + (result.get("message") or ""),
                )
            else:
                _append(
                    "system",
                    "❌ Release nie wystartował: " + (result.get("error") or "?"),
                )
            return self._json(code, result)

        return self._json(404, {"error": "nie ma takiego API"})


def _run_git(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=WORKSPACE,
        capture_output=True,
        text=True,
        timeout=120,
    )


def _workspace_status() -> dict:
    dirty = _run_git(["git", "status", "--porcelain"])
    branch = _run_git(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    head = _run_git(["git", "rev-parse", "--short", "HEAD"])
    remote = _run_git(["git", "remote", "get-url", "origin"])
    return {
        "workspace": WORKSPACE,
        "branch": (branch.stdout or "").strip(),
        "head": (head.stdout or "").strip(),
        "dirty": bool((dirty.stdout or "").strip()),
        "dirtyFiles": (dirty.stdout or "").strip().splitlines()[:30],
        "origin": (remote.stdout or "").strip(),
        "wipHint": (
            "Eksperymenty taty: ~/Dokumenty/Projekty/Learning-languages-wip "
            "(branch adam/wip). Portal i release = tylko ten katalog shared."
        ),
        "releasesUrl": "https://github.com/xhavsky/Learning-languages/releases",
    }


def _find_gh() -> str | None:
    gh = shutil.which("gh")
    if gh:
        return gh
    # NixOS often has gh via nix-shell; try common profile paths
    for p in (
        Path.home() / ".nix-profile/bin/gh",
        Path("/run/current-system/sw/bin/gh"),
    ):
        if p.is_file():
            return str(p)
    return None


def _trigger_release(kind: str) -> dict:
    """Push shared main (if needed) and dispatch GitHub Actions workflows."""
    st = _workspace_status()
    if st["dirty"]:
        return {
            "ok": False,
            "error": "W shared są niezapisane zmiany Gita. "
            "Najpierw niech asystent zacommituje na main, albo tata posprząta WIP.",
            "dirtyFiles": st["dirtyFiles"],
            "help": "Portal pracuje tylko w Learning-languages (shared). "
            "Brudne pliki nie powinny iść w paczkę.",
        }

    # Ensure we're on main for releases
    br = st["branch"]
    if br not in ("main", "master"):
        return {
            "ok": False,
            "error": f"Release tylko z main (teraz: {br}).",
        }

    # Push to origin so CI has latest
    push = _run_git(["git", "push", "origin", "HEAD:main"])
    if push.returncode != 0:
        err = (push.stderr or push.stdout or "")[-800:]
        return {
            "ok": False,
            "error": f"git push origin main nieudany:\n{err}",
            "help": "Tata musi być zalogowany do GitHub (SSH/credentials) na tym PC.",
        }

    gh = _find_gh()
    workflows = []
    if kind in ("windows", "both"):
        workflows.append("windows.yml")
    if kind in ("apk", "both"):
        workflows.append("android.yml")

    started = []
    errors = []
    if gh:
        for wf in workflows:
            r = subprocess.run(
                [gh, "workflow", "run", wf, "--ref", "main"],
                cwd=WORKSPACE,
                capture_output=True,
                text=True,
                timeout=60,
            )
            if r.returncode == 0:
                started.append(wf)
            else:
                errors.append(f"{wf}: {(r.stderr or r.stdout or '')[-400:]}")
    else:
        # Fallback: empty commit won't re-trigger path filters; tell user push already done
        return {
            "ok": True,
            "message": (
                "Wypchnięto main na GitHub. Brak `gh` CLI — otwórz Actions i "
                "uruchom ręcznie „Windows package” / „Android APK” (workflow_dispatch), "
                "albo poczekaj jeśli push i tak odpali CI.\n"
                "https://github.com/xhavsky/Learning-languages/actions"
            ),
            "pushed": True,
            "releasesUrl": st["releasesUrl"],
        }

    if errors and not started:
        return {"ok": False, "error": " | ".join(errors)}

    msg = (
        "Wypchnięto main. Uruchomiono: "
        + (", ".join(started) if started else "—")
        + ".\nPaczki: https://github.com/xhavsky/Learning-languages/releases\n"
        "Status buildów: https://github.com/xhavsky/Learning-languages/actions"
    )
    if errors:
        msg += "\nCzęściowe błędy: " + " | ".join(errors)
    return {
        "ok": True,
        "message": msg,
        "started": started,
        "pushed": True,
        "releasesUrl": st["releasesUrl"],
    }


def _github_publish(username: str, token: str, repo: str) -> dict:
    """Create repo on Anielka's account (if needed) and push current project."""
    import urllib.error
    import urllib.request

    api = f"https://api.github.com/repos/{username}/{repo}"
    req = urllib.request.Request(
        api,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "anielka-portal",
        },
    )
    exists = False
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            exists = resp.status == 200
    except urllib.error.HTTPError as e:
        if e.code != 404:
            body = e.read().decode("utf-8", "replace")
            return {
                "ok": False,
                "error": f"GitHub API: {e.code} {body[:400]}",
                "help": "Sprawdź token (musi mieć scope repo) i nazwę użytkownika.",
            }

    if not exists:
        create_req = urllib.request.Request(
            "https://api.github.com/user/repos",
            data=json.dumps(
                {
                    "name": repo,
                    "description": "Trener Językowy — Anielka",
                    "private": False,
                    "auto_init": False,
                }
            ).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/vnd.github+json",
                "Content-Type": "application/json",
                "User-Agent": "anielka-portal",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(create_req, timeout=30) as resp:
                if resp.status not in (200, 201):
                    return {"ok": False, "error": f"Nie udało się utworzyć repo ({resp.status})"}
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")
            return {
                "ok": False,
                "error": f"Tworzenie repo: {e.code} {body[:400]}",
                "help": "Token musi mieć uprawnienie repo. Nazwa repo nie może kolidować.",
            }

    remote = f"https://{username}:{token}@github.com/{username}/{repo}.git"
    # Push from workspace (do not store token in git config permanently)
    env = os.environ.copy()
    env["GIT_TERMINAL_PROMPT"] = "0"
    steps = []
    # Ensure we are in a git repo
    if not (Path(WORKSPACE) / ".git").exists():
        return {
            "ok": False,
            "error": "Na komputerze taty brak katalogu .git w projekcie.",
        }

    def run(args: list[str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            args,
            cwd=WORKSPACE,
            capture_output=True,
            text=True,
            env=env,
            timeout=180,
        )

    # Add temporary remote anielka-publish
    run(["git", "remote", "remove", "anielka-publish"])
    r = run(["git", "remote", "add", "anielka-publish", remote])
    if r.returncode != 0:
        return {"ok": False, "error": f"git remote add: {r.stderr}"}
    steps.append("remote OK")

    # Stage nothing extra — push current branch
    branch = run(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    br = (branch.stdout or "main").strip() or "main"
    push = run(["git", "push", "-u", "anielka-publish", f"HEAD:refs/heads/{br}"])
    # Always remove remote with token
    run(["git", "remote", "remove", "anielka-publish"])
    if push.returncode != 0:
        return {
            "ok": False,
            "error": f"git push nieudany:\n{(push.stderr or push.stdout)[-1500:]}",
            "help": (
                "Jeśli GitHub prosi o uprawnienia — token classic z 'repo'. "
                "Jeśli conflict — napisz do asystenta na czacie."
            ),
        }
    steps.append(f"push {br} OK")
    return {
        "ok": True,
        "url": f"https://github.com/{username}/{repo}",
        "branch": br,
        "steps": steps,
        "message": f"Gotowe! Twoje repo: https://github.com/{username}/{repo}",
    }


def main() -> int:
    DATA.mkdir(parents=True, exist_ok=True)
    _write_meta()
    threading.Thread(target=_worker, daemon=True).start()
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Portal Anielki → {TAILSCALE_URL}", flush=True)
    print(f"              → {TAILSCALE_IP_URL}", flush=True)
    print(f"PIN: {PIN}", flush=True)
    print(f"workspace: {WORKSPACE}", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("stop", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
