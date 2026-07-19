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
GH_IDENTITY = DATA / "github_identity.json"
LOCAL_BUSY = DATA / "local_busy.json"

HOST = os.environ.get("ANIELKA_PORTAL_HOST", "0.0.0.0")
PORT = int(os.environ.get("ANIELKA_PORTAL_PORT", "7474"))
PIN = os.environ.get("ANIELKA_PORTAL_PIN", "3141")
TAILSCALE_URL = os.environ.get(
    "ANIELKA_PORTAL_URL",
    "https://nixos.tail4caf1.ts.net:7475",
)
TAILSCALE_IP_URL = os.environ.get(
    "ANIELKA_PORTAL_IP_URL",
    "https://nixos.tail4caf1.ts.net:7475",
)
TAILSCALE_HTTP_URL = os.environ.get(
    "ANIELKA_PORTAL_HTTP_URL",
    "https://nixos.tail4caf1.ts.net:7475",
)

CURSOR_BIN = os.environ.get("CURSOR_BIN", shutil.which("cursor") or "cursor")
WORKSPACE = os.environ.get("ANIELKA_WORKSPACE", str(REPO))

_lock = threading.Lock()
_jobs: queue.Queue[str] = queue.Queue()
_busy = False
_progress: dict = {
    "busy": False,
    "percent": 0,
    "stage": "idle",
    "detail": "",
    "steps": [],
    "startedAt": None,
    "elapsedSec": 0,
    "toolCount": 0,
}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _read_local_busy_file() -> dict | None:
    """Busy flag written by Cursor project hooks (.cursor/hooks/portal-busy.sh)."""
    if not LOCAL_BUSY.exists():
        return None
    try:
        data = json.loads(LOCAL_BUSY.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not data.get("busy"):
        return None
    updated = data.get("updatedAt") or data.get("startedAt")
    if updated:
        try:
            age = (
                datetime.now(timezone.utc) - datetime.fromisoformat(updated)
            ).total_seconds()
            # Hooks should heartbeat; stale lock = ignore
            if age > 240:
                return None
        except ValueError:
            pass
    return data


def _detect_local_agent_process() -> bool:
    """Fallback: Cursor/agent process touching this workspace."""
    ws = str(Path(WORKSPACE).resolve())
    markers = (
        "cursor",
        "Cursor",
        "composer",
        "agent",
    )
    try:
        proc = Path("/proc")
        for entry in proc.iterdir():
            if not entry.name.isdigit():
                continue
            try:
                cmdline = (entry / "cmdline").read_bytes().replace(b"\x00", b" ")
                cmd = cmdline.decode("utf-8", "replace")
            except OSError:
                continue
            if ws not in cmd and "Learning-languages" not in cmd:
                # Also accept cwd == workspace
                try:
                    cwd = (entry / "cwd").resolve()
                    if str(cwd) != ws and not str(cwd).startswith(ws + os.sep):
                        continue
                except OSError:
                    continue
            low = cmd.lower()
            if not any(m.lower() in low for m in markers):
                continue
            # Ignore the portal itself / plain editors without agent
            if "anielka-portal" in low or "server.py" in low:
                continue
            if "cursor" in low or "composer" in low or "agent" in low:
                return True
    except OSError:
        return False
    return False


def _local_work_active() -> dict | None:
    """Return local-busy info for portal UI, or None."""
    file_busy = _read_local_busy_file()
    if file_busy:
        return file_busy
    if _detect_local_agent_process():
        return {
            "busy": True,
            "source": "process",
            "detail": "Tata ma otwartą lokalną sesję Cursora przy tym projekcie…",
            "updatedAt": _now(),
        }
    return None


def _progress_snapshot() -> dict:
    with _lock:
        p = dict(_progress)
        steps = list(_progress.get("steps") or [])
        files = list(_progress.get("recentFiles") or [])
    if p.get("startedAt"):
        try:
            start = datetime.fromisoformat(p["startedAt"])
            p["elapsedSec"] = max(
                0, int((datetime.now(timezone.utc) - start).total_seconds())
            )
        except ValueError:
            p["elapsedSec"] = 0
    p["steps"] = steps[-14:]
    p["recentFiles"] = files[-8:]
    p.pop("_lastStepKey", None)

    local = _local_work_active()
    if _busy:
        p["busy"] = True
        p["source"] = "portal"
        return p

    if local:
        started = local.get("startedAt") or local.get("updatedAt")
        elapsed = 0
        if started:
            try:
                elapsed = max(
                    0,
                    int(
                        (
                            datetime.now(timezone.utc) - datetime.fromisoformat(started)
                        ).total_seconds()
                    ),
                )
            except ValueError:
                elapsed = 0
        # Gentle pulse so the bar looks alive
        pulse = 28 + int(18 * (0.5 + 0.5 * __import__("math").sin(time.time() / 2.5)))
        path = local.get("path") or ""
        steps_local = [{"ts": _now(), "text": "Sesja lokalna (tata / Cursor)"}]
        if path:
            steps_local.append(
                {"ts": _now(), "text": "Plik: " + _short_path(str(path))}
            )
        return {
            "busy": True,
            "source": local.get("source") or "local",
            "percent": pulse,
            "stage": "local",
            "detail": local.get("detail")
            or "Tata pracuje lokalnie w Cursorze…",
            "steps": steps_local,
            "recentFiles": [_short_path(str(path))] if path else [],
            "startedAt": started,
            "elapsedSec": elapsed,
            "toolCount": 0,
            "headline": local.get("detail") or "Praca lokalna",
        }

    p["busy"] = False
    p["source"] = "idle"
    return p


def _combined_busy() -> bool:
    return bool(_busy or _local_work_active())


def _short_path(path: str) -> str:
    p = (path or "").strip().replace("\\", "/")
    if not p:
        return ""
    # Prefer path relative to workspace
    try:
        ws = str(Path(WORKSPACE).resolve())
        full = str(Path(p).resolve())
        if full.startswith(ws + os.sep):
            p = full[len(ws) + 1 :]
    except OSError:
        pass
    parts = [x for x in p.split("/") if x]
    if len(parts) <= 3:
        return "/".join(parts)
    return "/".join(parts[-3:])


def _extract_tool_meta(obj: dict) -> tuple[str, str]:
    """Return (tool_name, path_or_hint)."""
    tool = (
        obj.get("tool")
        or obj.get("name")
        or (obj.get("tool_call") or {}).get("name")
        or (obj.get("toolCall") or {}).get("name")
        or ""
    )
    if isinstance(tool, dict):
        tool = tool.get("name") or tool.get("tool") or ""

    inp = (
        obj.get("input")
        or obj.get("arguments")
        or obj.get("args")
        or (obj.get("tool_call") or {}).get("input")
        or (obj.get("toolCall") or {}).get("input")
        or {}
    )
    if isinstance(inp, str):
        try:
            inp = json.loads(inp)
        except json.JSONDecodeError:
            inp = {"_raw": inp}
    if not isinstance(inp, dict):
        inp = {}

    path = (
        inp.get("path")
        or inp.get("file_path")
        or inp.get("filePath")
        or inp.get("target_file")
        or inp.get("targetFile")
        or inp.get("filename")
        or ""
    )
    if not path and (inp.get("glob") or inp.get("glob_pattern") or inp.get("pattern")):
        path = str(
            inp.get("glob") or inp.get("glob_pattern") or inp.get("pattern") or ""
        )[:80]
    if not path and inp.get("command"):
        cmd = str(inp.get("command")).strip().replace("\n", " ")
        path = cmd[:70] + ("…" if len(cmd) > 70 else "")
    if not path and (inp.get("query") or inp.get("search_term")):
        path = str(inp.get("query") or inp.get("search_term") or "")[:70]

    return str(tool or ""), str(path or "")


def _set_progress(
    *,
    stage: str | None = None,
    detail: str | None = None,
    percent: int | None = None,
    bump: int = 0,
    step: str | None = None,
    step_key: str | None = None,
    path: str | None = None,
    reset: bool = False,
) -> None:
    global _progress
    with _lock:
        if reset:
            _progress = {
                "busy": True,
                "percent": 3,
                "stage": "start",
                "detail": "Startuję asystenta…",
                "steps": [],
                "recentFiles": [],
                "startedAt": _now(),
                "elapsedSec": 0,
                "toolCount": 0,
                "thinkingTicks": 0,
                "headline": "Start",
                "_lastStepKey": "",
            }
        if stage is not None:
            _progress["stage"] = stage
        if detail is not None:
            _progress["detail"] = detail
            _progress["headline"] = detail
        if percent is not None:
            _progress["percent"] = max(0, min(99, int(percent)))
        elif bump:
            _progress["percent"] = max(
                0, min(92, int(_progress.get("percent") or 0) + bump)
            )
        if path:
            short = _short_path(path)
            if short:
                files = list(_progress.get("recentFiles") or [])
                if not files or files[-1] != short:
                    files.append(short)
                _progress["recentFiles"] = files[-12:]

        if step:
            key = (step_key or step).strip().lower()
            steps = list(_progress.get("steps") or [])
            last_key = str(_progress.get("_lastStepKey") or "")
            if steps and last_key == key:
                # Merge duplicates: "Myślenie" → "Myślenie ×4"
                prev = steps[-1]
                count = int(prev.get("count") or 1) + 1
                base = prev.get("base") or prev.get("text") or step
                # Strip old ×N
                if " ×" in str(base):
                    base = str(base).split(" ×", 1)[0]
                steps[-1] = {
                    "ts": _now(),
                    "text": f"{base} ×{count}",
                    "base": base,
                    "count": count,
                }
            else:
                steps.append(
                    {
                        "ts": _now(),
                        "text": step,
                        "base": step,
                        "count": 1,
                    }
                )
                _progress["_lastStepKey"] = key
            _progress["steps"] = steps[-40:]
        _progress["busy"] = _busy


def _friendly_tool(name: str, path: str = "") -> str:
    n = (name or "").lower()
    mapping = [
        ("shell", "Terminal"),
        ("bash", "Terminal"),
        ("read", "Czytam"),
        ("write", "Zapisuję"),
        ("streplace", "Edytuję"),
        ("search_replace", "Edytuję"),
        ("grep", "Szukam w kodzie"),
        ("glob", "Szukam plików"),
        ("editnotebook", "Notebook"),
        ("todowrite", "Lista zadań"),
        ("webfetch", "Pobieram URL"),
        ("websearch", "Szukam w sieci"),
        ("delete", "Usuwam"),
        ("readlints", "Linter"),
    ]
    label = "Narzędzie"
    for key, lab in mapping:
        if key in n:
            label = lab
            break
    else:
        if name:
            label = str(name)
    short = _short_path(path) if path else ""
    if short:
        return f"{label}: {short}"
    return label


def _ingest_stream_event(obj: dict) -> None:
    """Update progress from Cursor agent stream-json event."""
    et = str(obj.get("type") or obj.get("event") or "").lower()
    subtype = str(obj.get("subtype") or "").lower()
    tool, path = _extract_tool_meta(obj)

    if et in ("system", "init", "status") and subtype in ("init", "started", ""):
        _set_progress(
            stage="start",
            detail="Asystent wystartował — łączę się z projektem",
            percent=8,
            step="Start sesji",
            step_key="start",
        )
        return

    if et in ("thinking", "reasoning") or "thinking" in et:
        with _lock:
            ticks = int(_progress.get("thinkingTicks") or 0) + 1
            _progress["thinkingTicks"] = ticks
            tools = int(_progress.get("toolCount") or 0)
        # Don't spam the timeline — one merged "Analizuję" entry + richer detail
        if tools == 0:
            detail = "Analizuję Twoją prośbę i planuję kroki…"
        else:
            detail = "Myślę nad kolejnym krokiem po ostatnich zmianach…"
        _set_progress(
            stage="thinking",
            detail=detail,
            bump=1 if ticks % 3 == 0 else 0,
            step="Analizuję",
            step_key="thinking",
        )
        return

    if et in ("assistant", "message", "text", "agent") and not tool:
        text = obj.get("text") or obj.get("content") or ""
        if isinstance(text, list):
            text = " ".join(
                str(p.get("text") or p) if isinstance(p, dict) else str(p) for p in text
            )
        snippet = str(text).strip().replace("\n", " ")
        # Ignore tiny/partial deltas for the step list
        if len(snippet) < 12:
            _set_progress(stage="writing", detail="Piszę odpowiedź…", bump=1)
            return
        short = snippet[:90] + ("…" if len(snippet) > 90 else "")
        _set_progress(
            stage="writing",
            detail=f"Piszę do Ciebie: {short}",
            bump=2,
            step="Piszę odpowiedź",
            step_key="writing",
        )
        return

    if et in ("tool_call", "tool_use", "tool", "function_call") or tool:
        label = _friendly_tool(str(tool), path)
        if subtype in ("completed", "end", "result", "success"):
            with _lock:
                _progress["toolCount"] = int(_progress.get("toolCount") or 0) + 1
                count = _progress["toolCount"]
            _set_progress(
                stage="tool",
                detail=f"✓ {label}  ·  łącznie {count} akcji",
                bump=4,
                step=f"✓ {label}",
                step_key=f"done:{tool}:{path}",
                path=path or None,
            )
        else:
            _set_progress(
                stage="tool",
                detail=f"Teraz: {label}",
                bump=5,
                step=label,
                step_key=f"run:{tool}:{path}",
                path=path or None,
            )
        return

    if et in ("result", "done", "completed"):
        with _lock:
            count = int(_progress.get("toolCount") or 0)
        detail = (
            f"Kończę — zrobiłem {count} akcji, składam odpowiedź…"
            if count
            else "Kończę i przygotowuję odpowiedź…"
        )
        _set_progress(
            stage="finishing",
            detail=detail,
            percent=95,
            step="Składam odpowiedź",
            step_key="finishing",
        )
        return


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
                "urlHttp": TAILSCALE_HTTP_URL,
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
                    "urlHttp": TAILSCALE_HTTP_URL,
                    "urlIp": TAILSCALE_IP_URL,
                    "pin": PIN,
                    "note": (
                        "Publiczny Funnel HTTPS — bez Tailscale. PIN wymagany."
                    ),
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
    except OSError:
        pass


SYSTEM_PREFIX = """Jesteś asystentem projektu „Trener Językowy” (Flutter).
To projekt Anielki. Katalog: {workspace}
Anielka i tata pracują nad TYM SAMYM kodem (gałąź main).
Zasady współpracy: jedna prośba naraz; gdy portal jest busy, tata nie edytuje równolegle;
nie dublujcie tej samej zmiany lokalnie i przez portal; commit przed release.
Anielka ma przez portal te same możliwości: zmiany w kodzie, commit na main, release.

{gh_block}

Odpowiadaj po polsku, krótko i jasno.
Wiadomość od Anielki:
"""


def _gh_prompt_block() -> str:
    ident = _load_gh_identity()
    if not ident:
        return (
            "Konto GitHub Anielki NIE jest jeszcze zapisane w portalu. "
            "Przy commitach możesz użyć autora „Anielka” i e-mail "
            "anielka@users.noreply.github.com, a poproś ją o „Zapisz konto” w sekcji GitHub."
        )
    name = ident.get("name") or ident["username"]
    email = ident.get("email") or f"{ident['username']}@users.noreply.github.com"
    return (
        f"Tożsamość Gita: GIT_AUTHOR_NAME/EMAIL są ustawione na konto Anielki ({name} <{email}>). "
        "Przy commitach NIE zmieniaj globalnego git config — używaj tych zmiennych "
        "(albo `git -c user.name=... -c user.email=... commit`). "
        "Commit ma być widoczny na GitHubie jako Anielka. Pushuj origin main; "
        "mirror na jej konto robi portal po sesji."
    )


def _load_gh_identity() -> dict | None:
    if not GH_IDENTITY.exists():
        return None
    try:
        data = json.loads(GH_IDENTITY.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not data.get("username") or not data.get("token"):
        return None
    return data


def _gh_identity_public(ident: dict | None = None) -> dict:
    ident = ident if ident is not None else _load_gh_identity()
    if not ident:
        return {"configured": False}
    token = str(ident.get("token") or "")
    masked = ""
    if len(token) > 8:
        masked = token[:4] + "…" + token[-4:]
    elif token:
        masked = "••••"
    return {
        "configured": True,
        "username": ident.get("username"),
        "name": ident.get("name") or ident.get("username"),
        "email": ident.get("email"),
        "repo": ident.get("repo") or "Learning-languages",
        "url": f"https://github.com/{ident.get('username')}/{ident.get('repo') or 'Learning-languages'}",
        "tokenMasked": masked,
        "savedAt": ident.get("savedAt"),
    }


def _fetch_github_profile(token: str) -> dict:
    import urllib.error
    import urllib.request

    req = urllib.request.Request(
        "https://api.github.com/user",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "anielka-portal",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        raise RuntimeError(f"GitHub /user: {e.code} {body[:300]}") from e


def _save_gh_identity(username: str, token: str, repo: str) -> dict:
    username = username.strip()
    token = token.strip()
    repo = (repo or "Learning-languages").strip() or "Learning-languages"
    if not username or not token:
        return {"ok": False, "error": "Podaj nazwę użytkownika i token."}
    try:
        profile = _fetch_github_profile(token)
    except Exception as e:  # noqa: BLE001
        return {
            "ok": False,
            "error": str(e),
            "help": "Token classic z scope repo; sprawdź też nazwę użytkownika.",
        }
    login = str(profile.get("login") or username)
    if login.lower() != username.lower():
        # Prefer actual login from token
        username = login
    uid = profile.get("id")
    noreply = (
        f"{uid}+{login}@users.noreply.github.com"
        if uid
        else f"{login}@users.noreply.github.com"
    )
    email = (profile.get("email") or "").strip() or noreply
    name = (profile.get("name") or "").strip() or login
    payload = {
        "username": username,
        "token": token,
        "repo": repo,
        "name": name,
        "email": email,
        "savedAt": _now(),
    }
    DATA.mkdir(parents=True, exist_ok=True)
    GH_IDENTITY.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    try:
        os.chmod(GH_IDENTITY, 0o600)
    except OSError:
        pass
    return {"ok": True, "identity": _gh_identity_public(payload)}


def _agent_git_env(base: dict | None = None) -> dict:
    env = (base or os.environ).copy()
    ident = _load_gh_identity()
    if ident:
        env["GIT_AUTHOR_NAME"] = ident.get("name") or ident["username"]
        env["GIT_AUTHOR_EMAIL"] = ident.get("email") or (
            f"{ident['username']}@users.noreply.github.com"
        )
        env["GIT_COMMITTER_NAME"] = env["GIT_AUTHOR_NAME"]
        env["GIT_COMMITTER_EMAIL"] = env["GIT_AUTHOR_EMAIL"]
        env["ANIELKA_GH_USER"] = ident["username"]
        env["ANIELKA_GH_REPO"] = ident.get("repo") or "Learning-languages"
    return env


def _mirror_to_anielka() -> dict | None:
    """Push current HEAD to Anielka's GitHub fork/repo (if identity saved)."""
    ident = _load_gh_identity()
    if not ident:
        return None
    result = _github_publish(
        ident["username"],
        ident["token"],
        ident.get("repo") or "Learning-languages",
    )
    return result


def _run_agent(user_text: str) -> str:
    prompt = SYSTEM_PREFIX.format(
        workspace=WORKSPACE,
        gh_block=_gh_prompt_block(),
    ) + user_text.strip()
    cmd = [
        CURSOR_BIN,
        "agent",
        "-p",
        "--force",
        "--trust",
        "--output-format",
        "stream-json",
        "--stream-partial-output",
        prompt,
    ]
    env = _agent_git_env()
    _set_progress(
        reset=True,
        stage="start",
        detail="Uruchamiam asystenta Cursor…",
        percent=5,
        step="Start asystenta",
    )

    try:
        proc = subprocess.Popen(
            cmd,
            cwd=WORKSPACE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env,
            bufsize=1,
        )
    except FileNotFoundError:
        return "Nie znaleziono `cursor` na komputerze taty. Tata musi mieć Cursor CLI."

    final_text_parts: list[str] = []
    stderr_chunks: list[str] = []
    deadline = time.time() + 900
    last_creep_sec = -1

    def _read_stderr() -> None:
        assert proc.stderr is not None
        for line in proc.stderr:
            stderr_chunks.append(line)
            if time.time() > deadline:
                break

    err_thread = threading.Thread(target=_read_stderr, daemon=True)
    err_thread.start()

    assert proc.stdout is not None
    try:
        while True:
            if time.time() > deadline:
                proc.kill()
                return "⏰ Agent pracował zbyt długo (timeout 15 min). Spróbuj krótszą prośbę."
            line = proc.stdout.readline()
            if not line:
                if proc.poll() is not None:
                    break
                # Soft heartbeat while waiting for next event
                with _lock:
                    pct = int(_progress.get("percent") or 10)
                    started = _progress.get("startedAt")
                    detail_now = _progress.get("detail") or "Nadal pracuję…"
                elapsed = 0
                if started:
                    try:
                        elapsed = int(
                            (
                                datetime.now(timezone.utc)
                                - datetime.fromisoformat(started)
                            ).total_seconds()
                        )
                    except ValueError:
                        elapsed = 0
                # Slow creep so the bar never looks frozen
                if (
                    pct < 85
                    and elapsed > 0
                    and elapsed % 8 == 0
                    and elapsed != last_creep_sec
                ):
                    last_creep_sec = elapsed
                    _set_progress(detail=detail_now, bump=1)
                time.sleep(0.15)
                continue

            raw = line.strip()
            if not raw:
                continue
            try:
                obj = json.loads(raw)
            except json.JSONDecodeError:
                # Fallback plain text line
                if raw and not raw.startswith("{"):
                    final_text_parts.append(raw)
                    _set_progress(
                        stage="writing",
                        detail="Piszę odpowiedź…",
                        bump=2,
                    )
                continue

            if not isinstance(obj, dict):
                continue
            _ingest_stream_event(obj)

            # Collect final / text payloads
            et = str(obj.get("type") or "").lower()
            if et in ("result", "done", "completed"):
                result = obj.get("result") or obj.get("text") or obj.get("message")
                if isinstance(result, dict):
                    result = result.get("text") or result.get("content") or ""
                if result:
                    final_text_parts.append(str(result).strip())
            elif et in ("assistant", "message", "text"):
                content = obj.get("text") or obj.get("content") or obj.get("message")
                if isinstance(content, dict):
                    content = content.get("content") or content.get("text") or ""
                if isinstance(content, list):
                    bits = []
                    for part in content:
                        if isinstance(part, dict):
                            bits.append(str(part.get("text") or ""))
                        else:
                            bits.append(str(part))
                    content = "".join(bits)
                if content and et == "result":
                    final_text_parts.append(str(content).strip())
                elif content and obj.get("subtype") in ("complete", "final", None):
                    # Keep last assistant text as candidate answer
                    final_text_parts.append(str(content).strip())
    finally:
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        err_thread.join(timeout=2)

    err = "".join(stderr_chunks).strip()
    # Prefer last non-empty collected chunk; dedupe consecutive duplicates
    parts = [p for p in final_text_parts if p]
    out = ""
    if parts:
        # Last substantial chunk is usually the final answer
        out = parts[-1]
        if len(out) < 40 and len(parts) > 1:
            out = "\n\n".join(parts[-3:])

    if proc.returncode not in (0, None) and not out:
        return f"Coś poszło nie tak (kod {proc.returncode}).\n{err[-2000:]}"
    if not out:
        # Last-resort: plain text mode if stream produced nothing useful
        _set_progress(
            stage="fallback",
            detail="Drugie podejście (tryb tekstowy)…",
            percent=40,
            step="Fallback text",
        )
        try:
            fallback = subprocess.run(
                [
                    CURSOR_BIN,
                    "agent",
                    "-p",
                    "--force",
                    "--trust",
                    "--output-format",
                    "text",
                    prompt,
                ],
                cwd=WORKSPACE,
                capture_output=True,
                text=True,
                timeout=900,
                env=env,
            )
            out = (fallback.stdout or "").strip() or (fallback.stderr or "").strip()
        except Exception as e:  # noqa: BLE001
            return f"Błąd agenta: {e}\n{err[-1500:]}"
    if not out:
        return err[-2000:] or "(pusta odpowiedź)"
    _set_progress(stage="done", detail="Gotowe!", percent=99, step="Gotowe")
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
        _set_progress(
            reset=True,
            stage="queued",
            detail="Przyjęłam prośbę — zaraz zaczynam",
            percent=4,
            step="W kolejce",
        )
        _append(
            "system",
            "🤖 Pracuję nad Twoją prośbą — śledź pasek postępu powyżej.",
            status="working",
        )
        try:
            answer = _run_agent(user["text"])
            _append("assistant", answer, replyTo=msg_id)
            # Mirror commits onto Anielka's GitHub so her account shows the work
            mirror = _mirror_to_anielka()
            if mirror:
                if mirror.get("ok"):
                    _append(
                        "system",
                        "🐙 Zsynchronizowano też na Twoje GitHub: "
                        + (mirror.get("url") or ""),
                        status="mirror-ok",
                    )
                else:
                    _append(
                        "system",
                        "⚠️ Nie udało się zsynchronizować na Twoje GitHub: "
                        + (mirror.get("error") or "?")
                        + "\nZapisz ponownie token w sekcji GitHub albo napisz tacie.",
                        status="mirror-fail",
                    )
        except Exception as e:  # noqa: BLE001
            _append("assistant", f"Błąd: {e}", replyTo=msg_id, status="error")
        finally:
            _busy = False
            with _lock:
                _progress["busy"] = False
                _progress["percent"] = 100
                _progress["stage"] = "idle"
                _progress["detail"] = "Gotowe"
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
                    "busy": _combined_busy(),
                    "progress": _progress_snapshot(),
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
            return self._json(
                200,
                {
                    "messages": chat,
                    "busy": _combined_busy(),
                    "progress": _progress_snapshot(),
                },
            )
        if path == "/api/progress":
            if not _check_pin(self):
                return self._json(401, {"error": "Zły PIN. Poproś tatę."})
            return self._json(200, _progress_snapshot())
        if path == "/api/status":
            if not _check_pin(self):
                return self._json(401, {"error": "Zły PIN. Poproś tatę."})
            return self._json(200, _workspace_status())
        if path == "/api/github-identity":
            if not _check_pin(self):
                return self._json(401, {"error": "Zły PIN. Poproś tatę."})
            return self._json(200, _gh_identity_public())
        if path.startswith("/static/"):
            rel = path.removeprefix("/static/")
            assets_img = (REPO / "assets" / "images").resolve()
            static_root = STATIC.resolve()
            candidates: list[Path] = [(STATIC / rel).resolve()]
            # /static/img/kitten_book.png also served from app assets
            if rel.startswith("img/"):
                candidates.append((assets_img / Path(rel).name).resolve())
            for f in candidates:
                allowed = str(f).startswith(str(static_root)) or str(f).startswith(
                    str(assets_img)
                )
                if not allowed or not f.is_file():
                    continue
                ctype = {
                    ".css": "text/css; charset=utf-8",
                    ".js": "application/javascript; charset=utf-8",
                    ".png": "image/png",
                    ".jpg": "image/jpeg",
                    ".jpeg": "image/jpeg",
                    ".webp": "image/webp",
                    ".svg": "image/svg+xml",
                    ".ico": "image/x-icon",
                    ".html": "text/html; charset=utf-8",
                }.get(f.suffix.lower(), "application/octet-stream")
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
            if _combined_busy() and not _busy:
                return self._json(
                    409,
                    {
                        "error": (
                            "Tata właśnie pracuje lokalnie w Cursorze. "
                            "Poczekaj, aż zniknie pasek postępu — wtedy wyślij prośbę."
                        )
                    },
                )
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

        if path == "/api/github-identity":
            if not _check_pin(self) and data.get("pin") != PIN:
                return self._json(401, {"error": "Zły PIN"})
            if data.get("clear"):
                try:
                    GH_IDENTITY.unlink(missing_ok=True)
                except OSError as e:
                    return self._json(500, {"ok": False, "error": str(e)})
                return self._json(200, {"ok": True, "identity": {"configured": False}})
            user = (data.get("username") or "").strip()
            token = (data.get("token") or "").strip()
            repo = (data.get("repo") or "Learning-languages").strip() or "Learning-languages"
            result = _save_gh_identity(user, token, repo)
            code = 200 if result.get("ok") else 400
            return self._json(code, result)

        if path == "/api/github-publish":
            if not _check_pin(self) and data.get("pin") != PIN:
                return self._json(401, {"error": "Zły PIN"})
            user = (data.get("username") or "").strip()
            token = (data.get("token") or "").strip()
            repo = (data.get("repo") or "Learning-languages").strip() or "Learning-languages"
            if not user or not token:
                # Fall back to saved identity
                ident = _load_gh_identity()
                if ident:
                    user = ident["username"]
                    token = ident["token"]
                    repo = repo or ident.get("repo") or "Learning-languages"
            if not user or not token:
                return self._json(
                    400,
                    {
                        "error": "Potrzebuję nazwy użytkownika GitHub i tokenu.",
                        "help": (
                            "1) Wejdź na https://github.com/settings/tokens\n"
                            "2) Generate new token (classic)\n"
                            "3) Zaznacz uprawnienie: repo\n"
                            "4) Skopiuj token i wklej tutaj razem z nazwą konta\n"
                            "5) Kliknij „Zapisz konto”, żeby portal pamiętał"
                        ),
                    },
                )
            saved = _save_gh_identity(user, token, repo)
            if not saved.get("ok"):
                return self._json(400, saved)
            result = _github_publish(user, token, repo)
            if result.get("ok"):
                result["identity"] = saved.get("identity")
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
        "note": (
            "Jeden wspólny projekt Anielki — portal i lokalna praca to to samo repo."
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
    """Push main (if needed) and dispatch GitHub Actions workflows."""
    st = _workspace_status()
    if st["dirty"]:
        return {
            "ok": False,
            "error": "W projekcie są niezapisane zmiany Gita. "
            "Najpierw poproś asystenta (lub tatę), żeby zacommitował na main.",
            "dirtyFiles": st["dirtyFiles"],
            "help": "To jeden wspólny projekt — commit na main, potem znowu Release.",
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
