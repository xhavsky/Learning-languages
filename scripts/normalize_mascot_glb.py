#!/usr/bin/env python3
"""Normalize Trellis mascot/prop GLBs so height (Y) matches a target.

Preserves textures/materials by rewriting POSITION accessors in-place
(and updating JSON min/max + padding). Does NOT re-export via trimesh
(which strips WebP textures).

Default: scale so robust Y extent (p1–p99) ≈ 1.0, center XZ at 0, min_y = 0.

Usage:
  python3 scripts/normalize_mascot_glb.py assets/models3d/mascot_dog.glb
  python3 scripts/normalize_mascot_glb.py --target-height 0.3 assets/models3d/bowl_pink.glb
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

import numpy as np

# glTF component types
_CT = {
    5120: ("b", 1),
    5121: ("B", 1),
    5122: ("h", 2),
    5123: ("H", 2),
    5125: ("I", 4),
    5126: ("f", 4),
}
_TYPE_N = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def _parse_glb(data: bytes) -> tuple[dict, memoryview, int]:
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError(f"not glTF: {magic!r}")
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
    bin_start = bin_off + 8
    return g, memoryview(data)[bin_start : bin_start + bin_len], bin_start


def _accessor_numpy(g: dict, blob: memoryview, acc_i: int) -> np.ndarray:
    acc = g["accessors"][acc_i]
    bv = g["bufferViews"][acc["bufferView"]]
    comp = acc["componentType"]
    fmt, nbytes = _CT[comp]
    ncomp = _TYPE_N[acc["type"]]
    count = acc["count"]
    offset = (bv.get("byteOffset") or 0) + (acc.get("byteOffset") or 0)
    stride = bv.get("byteStride") or (nbytes * ncomp)
    if stride == nbytes * ncomp and comp == 5126:
        return np.frombuffer(blob, dtype=np.float32, count=count * ncomp, offset=offset).reshape(
            count, ncomp
        ).copy()
    # strided / non-float fallback
    out = np.empty((count, ncomp), dtype=np.float64)
    for i in range(count):
        o = offset + i * stride
        vals = struct.unpack_from("<" + fmt * ncomp, blob, o)
        out[i] = vals
    return out.astype(np.float32)


def _write_accessor(g: dict, blob_mut: bytearray, acc_i: int, arr: np.ndarray) -> None:
    acc = g["accessors"][acc_i]
    bv = g["bufferViews"][acc["bufferView"]]
    comp = acc["componentType"]
    if comp != 5126:
        raise ValueError(f"only float POSITION rewrite supported, got {comp}")
    ncomp = _TYPE_N[acc["type"]]
    count = acc["count"]
    assert arr.shape == (count, ncomp)
    offset = (bv.get("byteOffset") or 0) + (acc.get("byteOffset") or 0)
    stride = bv.get("byteStride") or (4 * ncomp)
    flat = np.ascontiguousarray(arr, dtype=np.float32)
    if stride == 4 * ncomp:
        blob_mut[offset : offset + count * ncomp * 4] = flat.tobytes()
    else:
        raw = flat.tobytes()
        for i in range(count):
            o = offset + i * stride
            blob_mut[o : o + 4 * ncomp] = raw[i * 4 * ncomp : (i + 1) * 4 * ncomp]
    mins = flat.min(axis=0).tolist()
    maxs = flat.max(axis=0).tolist()
    acc["min"] = [float(x) for x in mins]
    acc["max"] = [float(x) for x in maxs]


def _position_accessors(g: dict) -> list[int]:
    out: list[int] = []
    for mesh in g.get("meshes") or []:
        for prim in mesh.get("primitives") or []:
            ai = (prim.get("attributes") or {}).get("POSITION")
            if ai is not None and ai not in out:
                out.append(ai)
    return out


def _robust_bounds(verts: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    if len(verts) < 32:
        return verts.min(axis=0), verts.max(axis=0)
    lo = np.percentile(verts, 1, axis=0)
    hi = np.percentile(verts, 99, axis=0)
    if np.any(hi - lo < 1e-12):
        return verts.min(axis=0), verts.max(axis=0)
    return lo.astype(np.float64), hi.astype(np.float64)


def _pack_glb(g: dict, bin_blob: bytes) -> bytes:
    json_str = json.dumps(g, separators=(",", ":"), ensure_ascii=False)
    json_bytes = json_str.encode("utf-8")
    # pad JSON to 4-byte boundary with spaces
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


def normalize_glb(
    path: Path,
    *,
    target_height: float = 1.0,
    dry_run: bool = False,
) -> dict:
    path = path.resolve()
    data = bytearray(path.read_bytes())
    # Parse with a snapshot (JSON may move; work on copies)
    raw = bytes(data)
    g, blob_view, bin_start = _parse_glb(raw)
    blob = bytearray(blob_view)

    pos_ids = _position_accessors(g)
    if not pos_ids:
        raise RuntimeError(f"{path}: no POSITION accessors")

    # Gather all verts (first accessor drives transform; all get same affine)
    chunks = [_accessor_numpy(g, memoryview(blob), ai) for ai in pos_ids]
    all_v = np.concatenate(chunks, axis=0).astype(np.float64)

    before_min = all_v.min(axis=0)
    before_max = all_v.max(axis=0)
    before_ext = before_max - before_min

    lo, hi = _robust_bounds(all_v)
    height = float(hi[1] - lo[1])
    if height < 1e-12:
        height = float(before_ext[1]) if before_ext[1] > 1e-12 else float(before_ext.max())
    if height < 1e-12:
        raise RuntimeError(f"{path}: degenerate mesh")

    scale = target_height / height
    # After uniform scale: center robust XZ, put full min_y at 0
    mid_x = 0.5 * (lo[0] + hi[0]) * scale
    mid_z = 0.5 * (lo[2] + hi[2]) * scale
    min_y = float(all_v[:, 1].min()) * scale
    offset = np.array([-mid_x, -min_y, -mid_z], dtype=np.float64)

    info_before = {
        "min": before_min.tolist(),
        "max": before_max.tolist(),
        "extents": before_ext.tolist(),
        "max_extent": float(before_ext.max()),
        "height_Y": float(before_ext[1]),
    }

    print(f"=== {path.name}")
    print(f"  BEFORE min={info_before['min']}")
    print(f"  BEFORE max={info_before['max']}")
    print(
        f"  BEFORE extents={info_before['extents']} "
        f"max_extent={info_before['max_extent']:.6f}"
    )
    print(f"  scale={scale:.6f} target_height={target_height} offset={offset.tolist()}")

    # Material peek
    for i, m in enumerate(g.get("materials") or []):
        pbr = m.get("pbrMetallicRoughness") or {}
        print(
            f"  material[{i}] baseColor={pbr.get('baseColorFactor')} "
            f"metallic={pbr.get('metallicFactor')} rough={pbr.get('roughnessFactor')} "
            f"emissive={m.get('emissiveFactor')} "
            f"baseColorTex={pbr.get('baseColorTexture')} "
            f"mrTex={pbr.get('metallicRoughnessTexture')} "
            f"images={len(g.get('images') or [])}"
        )

    if dry_run:
        print("  dry-run: not writing")
        return {"file": str(path), "before": info_before, "scale": scale}

    for ai, arr in zip(pos_ids, chunks):
        v = arr.astype(np.float64) * scale + offset
        _write_accessor(g, blob, ai, v.astype(np.float32))

    after_chunks = [_accessor_numpy(g, memoryview(blob), ai) for ai in pos_ids]
    after_v = np.concatenate(after_chunks, axis=0).astype(np.float64)
    after_min = after_v.min(axis=0)
    after_max = after_v.max(axis=0)
    after_ext = after_max - after_min
    info_after = {
        "min": after_min.tolist(),
        "max": after_max.tolist(),
        "extents": after_ext.tolist(),
        "max_extent": float(after_ext.max()),
        "height_Y": float(after_ext[1]),
    }
    print(f"  AFTER  min={info_after['min']}")
    print(f"  AFTER  max={info_after['max']}")
    print(
        f"  AFTER  extents={info_after['extents']} "
        f"max_extent={info_after['max_extent']:.6f}"
    )

    out_bytes = _pack_glb(g, bytes(blob))
    out_tmp = path.with_suffix(".normalized.glb")
    out_tmp.write_bytes(out_bytes)
    out_tmp.replace(path)
    print(f"  wrote {path} ({path.stat().st_size} bytes) images={len(g.get('images') or [])}")
    return {"file": str(path), "before": info_before, "after": info_after, "scale": scale}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("paths", nargs="+", type=Path)
    ap.add_argument("--target-height", type=float, default=1.0)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    for p in args.paths:
        if not p.is_file():
            print(f"MISSING {p}", file=sys.stderr)
            return 1
        normalize_glb(p, target_height=args.target_height, dry_run=args.dry_run)
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
