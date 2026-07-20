#!/usr/bin/env python3
"""Convert embedded WebP images inside GLB/glTF to PNG.

Rewrites image bufferViews + mimeType only. Meshes/accessors stay byte-identical
(same vertex/index/UV/normal payloads), only image bytes and buffer offsets change.

Usage:
  python3 scripts/glb_webp_to_png.py assets/models3d/mascot_dog.glb
  python3 scripts/glb_webp_to_png.py --inplace assets/models3d/*.glb
"""
from __future__ import annotations

import argparse
import io
import json
import struct
import sys
from pathlib import Path

from PIL import Image


def _parse_glb(data: bytes) -> tuple[dict, bytes]:
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError(f"not glTF: {magic!r}")
    if version != 2:
        raise ValueError(f"unsupported glTF version: {version}")
    json_len, json_type = struct.unpack_from("<I4s", data, 12)
    if json_type != b"JSON":
        raise ValueError(f"chunk0 not JSON: {json_type!r}")
    g = json.loads(data[20 : 20 + json_len].decode("utf-8"))
    bin_off = 20 + json_len
    if bin_off + 8 > len(data):
        raise ValueError("no BIN chunk")
    bin_len, bin_type = struct.unpack_from("<I4s", data, bin_off)
    if bin_type != b"BIN\x00":
        raise ValueError(f"chunk1 not BIN: {bin_type!r}")
    blob = data[bin_off + 8 : bin_off + 8 + bin_len]
    return g, blob


def _pack_glb(g: dict, bin_blob: bytes) -> bytes:
    json_bytes = json.dumps(g, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_pad = (4 - (len(json_bytes) % 4)) % 4
    json_bytes = json_bytes + (b" " * json_pad)
    bin_pad = (4 - (len(bin_blob) % 4)) % 4
    bin_bytes = bin_blob + (b"\x00" * bin_pad)
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
    out = bytearray()
    out += struct.pack("<4sII", b"glTF", 2, total)
    out += struct.pack("<I4s", len(json_bytes), b"JSON")
    out += json_bytes
    out += struct.pack("<I4s", len(bin_bytes), b"BIN\x00")
    out += bin_bytes
    return bytes(out)


def _is_webp(raw: bytes, mime: str | None) -> bool:
    if mime and mime.lower() == "image/webp":
        return True
    return len(raw) >= 12 and raw[:4] == b"RIFF" and raw[8:12] == b"WEBP"


def _webp_to_png_bytes(raw: bytes) -> bytes:
    img = Image.open(io.BytesIO(raw))
    img.load()
    # Preserve alpha when present
    if img.mode not in ("RGB", "RGBA"):
        img = img.convert("RGBA" if "A" in img.getbands() else "RGB")
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def _align4(n: int) -> int:
    return (n + 3) & ~3


def convert_glb(path: Path, *, inplace: bool = False, out: Path | None = None) -> dict:
    path = path.resolve()
    data = path.read_bytes()
    g, blob = _parse_glb(data)

    views = g.get("bufferViews") or []
    if not views:
        raise RuntimeError(f"{path}: no bufferViews")

    # Snapshot each bufferView payload (mesh data stays identical)
    payloads: list[bytes] = []
    for bv in views:
        off = bv.get("byteOffset") or 0
        ln = bv["byteLength"]
        payloads.append(bytes(blob[off : off + ln]))

    images = g.get("images") or []
    converted = 0
    skipped = 0
    details: list[dict] = []

    for i, im in enumerate(images):
        if "bufferView" not in im:
            skipped += 1
            details.append({"image": i, "status": "skipped_uri", "mime": im.get("mimeType")})
            continue
        bvi = im["bufferView"]
        raw = payloads[bvi]
        mime = im.get("mimeType")
        if not _is_webp(raw, mime):
            skipped += 1
            details.append(
                {
                    "image": i,
                    "status": "unchanged",
                    "mime": mime,
                    "bytes": len(raw),
                }
            )
            continue
        png = _webp_to_png_bytes(raw)
        payloads[bvi] = png
        im["mimeType"] = "image/png"
        converted += 1
        details.append(
            {
                "image": i,
                "status": "webp->png",
                "bytes_in": len(raw),
                "bytes_out": len(png),
            }
        )

    # Rebuild contiguous BIN; keep 4-byte alignment between views
    new_blob = bytearray()
    for i, (bv, payload) in enumerate(zip(views, payloads)):
        pad = _align4(len(new_blob)) - len(new_blob)
        if pad:
            new_blob += b"\x00" * pad
        bv["byteOffset"] = len(new_blob)
        bv["byteLength"] = len(payload)
        bv["buffer"] = 0
        new_blob += payload

    # Final buffer pad to 4
    pad = _align4(len(new_blob)) - len(new_blob)
    if pad:
        new_blob += b"\x00" * pad

    if "buffers" not in g or not g["buffers"]:
        g["buffers"] = [{"byteLength": len(new_blob)}]
    else:
        g["buffers"][0]["byteLength"] = len(new_blob)
        # Drop URI if present (embedded only)
        g["buffers"][0].pop("uri", None)

    out_bytes = _pack_glb(g, bytes(new_blob))
    if out is None:
        out = path if inplace else path.with_name(path.stem + "_png.glb")
    out.write_bytes(out_bytes)

    info = {
        "file": str(path),
        "out": str(out),
        "converted": converted,
        "skipped": skipped,
        "size_in": path.stat().st_size if path.exists() else None,
        "size_out": out.stat().st_size,
        "details": details,
    }
    print(f"=== {path.name}")
    print(f"  converted={converted} skipped={skipped}")
    for d in details:
        print(f"  {d}")
    print(f"  wrote {out} ({out.stat().st_size} bytes)")
    return info


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("paths", nargs="+", type=Path)
    ap.add_argument("--inplace", action="store_true", help="overwrite input GLB")
    ap.add_argument("-o", "--output", type=Path, help="single-file output path")
    args = ap.parse_args()
    if args.output and len(args.paths) != 1:
        print("--output requires exactly one input", file=sys.stderr)
        return 1
    for p in args.paths:
        if not p.is_file():
            print(f"MISSING {p}", file=sys.stderr)
            return 1
        convert_glb(p, inplace=args.inplace, out=args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
