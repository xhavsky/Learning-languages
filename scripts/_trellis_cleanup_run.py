#!/usr/bin/env python3
"""Cancel Adam Trellis jobs, copy good GLBs, restart mascot generator. No bash required."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API = os.environ.get("TRELLIS_URL", "http://127.0.0.1:8004")
ROOT = Path("/home/adam/Dokumenty/Projekty/Learning-languages")
OUT = ROOT / "assets" / "models3d"
SCRIPT = ROOT / "scripts" / "generate_mascot_3d_trellis.sh"
LOG = Path("/tmp/trellis-mascot-gen.log")
PIDFILE = Path("/tmp/trellis-mascot-gen.pid")
BASH = "/nix/store/gik3rh1vz2jlgnifb9dh6vc6sxwwz9jj-bash-5.3p9/bin/bash"
PY = "/nix/store/mj8b2zc2i4f77ak89k1fckgs40dqa09n-python3-3.13.13-env/bin/python3"
TRELLIS_OUT = Path("/var/lib/trellis3d/output")

GOOD = {
    "mascot_cat": "cc6ac0bcb72e",
    "mascot_dog": "4f9dccbf9cfe",
    "dress_sparkle": "98d1b5d87da7",
    "bowl_pink": "c2d24e3cae66",
    "bowl_gold": "8b8026ce94d7",
    "bed_soft": "9e52f2142771",
}
BAD_LOCAL = ["bow_gold", "scarf_rainbow", "boots_pink", "tiara_crystal"]
REPORT: dict = {"cancelled": [], "copied": [], "deleted_local": [], "errors": []}


def http_json(method: str, url: str, body: dict | None = None, timeout: int = 30):
    data = None
    headers = {}
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
        if not raw:
            return None
        return json.loads(raw)


def cancel_adam_jobs():
    try:
        q = http_json("GET", f"{API}/queue")
    except Exception as e:
        REPORT["errors"].append(f"queue fetch: {e}")
        q = {}
    jobs = []
    if q.get("running") and isinstance(q["running"], dict):
        jobs.append(q["running"])
    jobs.extend(q.get("queued") or [])
    # Also try known leftover IDs from prior script state
    known = [
        "1263e865419a4491",
        "6ed6a0a6c3ee4ef3",
        "e5b39ed827c4456a",
        "f51608bf4cdb4489",
        "c748029a22364e57",
        "668d63caa5204bf9",
        "aa1fe884e5f34155",
        "398f3f046d384845",
        "1391414d85d141d8",
        "68c4e80703b24631",
        "1fca1f86768947d0",
        "19b93622cde34001",
    ]
    seen = {j.get("job_id") for j in jobs if j}
    for jid in known:
        if jid not in seen:
            jobs.append({"job_id": jid, "user": "Adam"})

    for j in jobs:
        if not j:
            continue
        jid = j.get("job_id")
        user = j.get("user", "Adam")
        prompt = (j.get("prompt") or j.get("prompt_preview") or "").lower()
        if user == "Kamil":
            if not any(x in prompt for x in ("language-learning", "mascot", "kawaii", "kicia")):
                REPORT["cancelled"].append({"job_id": jid, "skipped": "kamil-unrelated"})
                continue
        if user not in ("Adam", "Kamil") and user != "Adam":
            # only Adam unless Kamil mascot
            if user != "Adam":
                continue
        if not jid:
            continue
        try:
            resp = http_json("POST", f"{API}/cancel/{jid}", {"user": "Adam"})
            REPORT["cancelled"].append({"job_id": jid, "user": user, "resp": resp})
        except Exception as e:
            REPORT["cancelled"].append({"job_id": jid, "error": str(e)})


def delete_bad_local():
    OUT.mkdir(parents=True, exist_ok=True)
    for name in BAD_LOCAL:
        p = OUT / f"{name}.glb"
        if p.exists():
            p.unlink()
            REPORT["deleted_local"].append(str(p))


def copy_good():
    OUT.mkdir(parents=True, exist_ok=True)
    for asset, out_id in GOOD.items():
        dest = OUT / f"{asset}.glb"
        src = TRELLIS_OUT / f"{out_id}.glb"
        if dest.exists() and dest.stat().st_size > 10000:
            REPORT["copied"].append({"asset": asset, "status": "already", "size": dest.stat().st_size})
            continue
        ok = False
        if src.exists() and src.stat().st_size > 10000:
            try:
                shutil.copy2(src, dest)
                ok = True
                REPORT["copied"].append({"asset": asset, "via": "fs", "size": dest.stat().st_size, "out_id": out_id})
            except Exception as e:
                REPORT["errors"].append(f"copy {asset} fs: {e}")
        if not ok:
            url = f"{API}/view/{out_id}.glb"
            try:
                partial = dest.with_suffix(".glb.partial")
                urllib.request.urlretrieve(url, partial)
                partial.replace(dest)
                REPORT["copied"].append({"asset": asset, "via": "http", "size": dest.stat().st_size, "out_id": out_id})
            except Exception as e:
                REPORT["errors"].append(f"copy {asset} http: {e}")


def verify_prompts() -> bool:
    text = SCRIPT.read_text()
    return "naked fur only" in text and "NO cat, NO dog" in text


def restart_generator():
    if not verify_prompts():
        REPORT["errors"].append("prompts not updated yet")
        return
    # stop old
    if PIDFILE.exists():
        try:
            old = int(PIDFILE.read_text().strip())
            os.kill(old, 15)
            time.sleep(0.5)
        except Exception:
            pass
    bash = BASH if Path(BASH).exists() else shutil.which("bash") or "/bin/bash"
    env = os.environ.copy()
    # ensure curl/python on PATH for the script
    env["PATH"] = f"/run/current-system/sw/bin:/nix/store/mj8b2zc2i4f77ak89k1fckgs40dqa09n-python3-3.13.13-env/bin:" + env.get("PATH", "")
    logf = open(LOG, "w")
    proc = subprocess.Popen(
        [bash, str(SCRIPT)],
        cwd=str(ROOT),
        stdout=logf,
        stderr=subprocess.STDOUT,
        env=env,
        start_new_session=True,
    )
    PIDFILE.write_text(str(proc.pid))
    REPORT["pid"] = proc.pid
    REPORT["log"] = str(LOG)
    time.sleep(2)
    REPORT["log_tail"] = LOG.read_text()[-1500:] if LOG.exists() else ""


def main():
    cancel_adam_jobs()
    delete_bad_local()
    copy_good()
    try:
        q = http_json("GET", f"{API}/queue")
        REPORT["queue_after"] = q
    except Exception as e:
        REPORT["queue_after"] = {"error": str(e)}
    restart_generator()
    out = Path("/tmp/trellis-cleanup-report.json")
    out.write_text(json.dumps(REPORT, indent=2, ensure_ascii=False))
    print(json.dumps(REPORT, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
