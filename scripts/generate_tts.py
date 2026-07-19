#!/usr/bin/env python3
"""Generate offline TTS mp3 assets for Trener Językowy from baza.json.

Primary engine: Piper (local ONNX) with female Amy / Spanish sharvard.
Optional: COQUI via TTS_URL (XTTS tutor_female) when that stack works.

Never called from the Flutter app at runtime.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BAZA = ROOT / "assets" / "data" / "baza.json"
AUDIO_DIR = ROOT / "assets" / "audio"
MANIFEST = AUDIO_DIR / "manifest.json"
VOICES = ROOT / "tools" / "voices"

# Prefer env; coqui lazy-proxy :8000 → upstream :18000 when healthy.
TTS_URL = os.environ.get("TTS_URL", "http://127.0.0.1:18000/v1/audio/speech")
USE_COQUI = os.environ.get("USE_COQUI", "0") == "1"
COQUI_VOICE = "tutor_female"
COQUI_MODEL = "tts-1-hd"

LANG_MAP = {
    "Angielski": "en",
    "Hiszpański": "es",
    # Cyrylica — Piper Amy nie czyta RU; pomijamy (klawiatura Anielki bez audio).
    "Rosyjski": None,
    "Rosyjski (zapis fonetyczny)": "en",
}

PIPER_MODELS = {
    "en": VOICES / "en_US-amy-medium.onnx",
    "es": VOICES / "es_ES-sharvard-medium.onnx",
}


def slug(text: str) -> str:
    s = text.strip().lower()
    s = re.sub(r"[^\w\s-]", "", s, flags=re.UNICODE)
    s = re.sub(r"[\s_]+", "_", s)
    return s[:48] or "x"


def audio_key(lang_code: str, text: str) -> str:
    h = hashlib.sha1(f"{lang_code}|{text}".encode("utf-8")).hexdigest()[:10]
    return f"{lang_code}_{slug(text)}_{h}.mp3"


def wav_to_mp3(wav: Path, mp3: Path) -> None:
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-loglevel",
            "error",
            "-i",
            str(wav),
            "-codec:a",
            "libmp3lame",
            "-qscale:a",
            "4",
            str(mp3),
        ],
        check=True,
    )


def synthesize_piper(text: str, lang_code: str, out_mp3: Path) -> None:
    model = PIPER_MODELS.get(lang_code, PIPER_MODELS["en"])
    if not model.exists():
        raise FileNotFoundError(f"missing piper model: {model}")
    piper = shutil.which("piper")
    if not piper:
        raise RuntimeError("piper not found on PATH")
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "out.wav"
        proc = subprocess.run(
            [piper, "-m", str(model), "-f", str(wav)],
            input=text.encode("utf-8"),
            capture_output=True,
            check=False,
        )
        if proc.returncode != 0 or not wav.exists() or wav.stat().st_size < 100:
            raise RuntimeError(
                f"piper failed: {proc.stderr.decode('utf-8', 'replace')}"
            )
        wav_to_mp3(wav, out_mp3)


def synthesize_coqui(text: str, out_mp3: Path, retries: int = 5) -> None:
    payload = json.dumps(
        {"input": text, "voice": COQUI_VOICE, "model": COQUI_MODEL},
        ensure_ascii=False,
    ).encode("utf-8")
    req = urllib.request.Request(
        TTS_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    last_err: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                data = resp.read()
            if len(data) < 500:
                raise RuntimeError(f"too small response ({len(data)} bytes)")
            out_mp3.write_bytes(data)
            return
        except Exception as e:  # noqa: BLE001
            last_err = e
            time.sleep(min(20, 3 * attempt))
    raise RuntimeError(f"coqui TTS failed for {text!r}: {last_err}")


def synthesize(text: str, lang_code: str, out_mp3: Path) -> str:
    if USE_COQUI:
        synthesize_coqui(text, out_mp3)
        return "coqui/tutor_female"
    synthesize_piper(text, lang_code, out_mp3)
    engine = "piper/amy" if lang_code == "en" else "piper/sharvard"
    return engine


def main() -> int:
    if not BAZA.exists():
        print(f"missing {BAZA}", file=sys.stderr)
        return 1
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    baza = json.loads(BAZA.read_text(encoding="utf-8"))
    manifest: dict = {
        "engine": "piper" if not USE_COQUI else "coqui",
        "voice": "amy+sharvard" if not USE_COQUI else COQUI_VOICE,
        "note": "XTTS tutor_female kept as tools/voices/tutor_female_xtts_ref.wav; "
        "USE_COQUI=1 when openedai-speech XTTS is healthy.",
        "entries": {},
    }
    if MANIFEST.exists():
        try:
            old = json.loads(MANIFEST.read_text(encoding="utf-8"))
            manifest["entries"] = old.get("entries", {})
        except json.JSONDecodeError:
            pass

    total = done = skipped = 0
    for lang_name, words in baza.items():
        lang_code = LANG_MAP.get(lang_name, "en")
        if lang_code is None:
            print(f"skip-lang {lang_name} (brak silnika TTS)")
            skipped += len(words)
            continue
        for w in words:
            obcy = (w.get("obcy") or "").strip()
            if not obcy:
                continue
            total += 1
            fname = audio_key(lang_code, obcy)
            out = AUDIO_DIR / fname
            key = f"{lang_name}|{obcy}"
            if out.exists() and out.stat().st_size > 500:
                print(f"skip  {fname}")
                manifest["entries"][key] = {
                    "file": fname,
                    "lang": lang_code,
                    "text": obcy,
                    "pl": w.get("pl", ""),
                }
                done += 1
                continue
            print(f"gen   {fname}  ({obcy!r}, {lang_code})")
            engine = synthesize(obcy, lang_code, out)
            manifest["entries"][key] = {
                "file": fname,
                "lang": lang_code,
                "text": obcy,
                "pl": w.get("pl", ""),
                "engine": engine,
            }
            done += 1
            print(f"  ok   {out.stat().st_size} bytes via {engine}")

    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    (AUDIO_DIR / ".gitkeep").touch()
    print(f"done {done}/{total} (pominięte języki: {skipped}) → {MANIFEST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
