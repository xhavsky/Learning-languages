#!/usr/bin/env python3
"""Diagnose Trellis GLB scale for model_viewer_plus (mascot tiny-green-dot)."""
from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

PATHS = [
    Path("/home/adam/Dokumenty/Projekty/Learning-languages/assets/models3d/mascot_dog.glb"),
    Path("/home/adam/Dokumenty/Projekty/Learning-languages/assets/models3d/mascot_cat.glb"),
]


def peek_header(path: Path) -> None:
    data = path.read_bytes()[:12]
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    print(f"=== {path}")
    print(f"size_bytes {path.stat().st_size}")
    print(f"magic {magic!r} version {version} declared_length {length}")
    print(f"hex12 {data.hex()}")


def glb_json(path: Path) -> dict:
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError(f"not glTF magic: {magic!r}")
    json_len, json_type = struct.unpack_from("<I4s", data, 12)
    if json_type != b"JSON":
        raise ValueError(f"chunk0 not JSON: {json_type!r}")
    return json.loads(data[20 : 20 + json_len])


def accessor_bounds(g: dict) -> tuple[list[float], list[float]] | None:
    mins: list[float] | None = None
    maxs: list[float] | None = None
    for mesh in g.get("meshes") or []:
        for prim in mesh.get("primitives") or []:
            acc_i = (prim.get("attributes") or {}).get("POSITION")
            if acc_i is None:
                continue
            acc = g["accessors"][acc_i]
            a_min = acc.get("min")
            a_max = acc.get("max")
            if not a_min or not a_max:
                continue
            if mins is None:
                mins, maxs = list(a_min[:3]), list(a_max[:3])
            else:
                mins = [min(mins[i], a_min[i]) for i in range(3)]
                maxs = [max(maxs[i], a_max[i]) for i in range(3)]
    if mins is None or maxs is None:
        return None
    return mins, maxs


def mat4_mul_point(m: list[float], p: list[float]) -> list[float]:
    x, y, z = p
    return [
        m[0] * x + m[4] * y + m[8] * z + m[12],
        m[1] * x + m[5] * y + m[9] * z + m[13],
        m[2] * x + m[6] * y + m[10] * z + m[14],
    ]


def node_local_matrix(node: dict) -> list[float]:
    if "matrix" in node:
        return list(node["matrix"])
    # T * R * S — approximate with scale+translation if no quat (common Trellis)
    sx, sy, sz = (node.get("scale") or [1, 1, 1])[:3]
    tx, ty, tz = (node.get("translation") or [0, 0, 0])[:3]
    # ignore rotation for quick extent estimate if present; print warning
    if "rotation" in node:
        # full TRS would need quat; use identity R for rough scale*translation box
        pass
    return [
        sx,
        0,
        0,
        0,
        0,
        sy,
        0,
        0,
        0,
        0,
        sz,
        0,
        tx,
        ty,
        tz,
        1,
    ]


def walk_world_bounds(g: dict) -> None:
    nodes = g.get("nodes") or []
    print(f"nodes {len(nodes)} meshes {len(g.get('meshes') or [])}")
    for i, n in enumerate(nodes):
        bits = []
        if "scale" in n:
            bits.append(f"scale={n['scale']}")
        if "translation" in n:
            bits.append(f"translation={n['translation']}")
        if "matrix" in n:
            bits.append(f"matrix[0:4]={n['matrix'][:4]} ...")
        if "mesh" in n:
            bits.append(f"mesh={n['mesh']}")
        if bits:
            print(f"  node[{i}] name={n.get('name')!r} {' '.join(bits)}")

    ab = accessor_bounds(g)
    if ab:
        mins, maxs = ab
        ext = [maxs[i] - mins[i] for i in range(3)]
        print(f"accessor_POSITION min {mins}")
        print(f"accessor_POSITION max {maxs}")
        print(f"accessor_POSITION extents {ext}")
        print(f"accessor_POSITION diagonal {sum(e * e for e in ext) ** 0.5:.6f}")
    else:
        print("accessor_POSITION bounds unavailable (no min/max on accessors)")

    # Heuristic: largest |scale| component across nodes
    scales = []
    for n in nodes:
        if "scale" in n:
            scales.append(n["scale"])
    if scales:
        print(f"node_scales_sample {scales[:8]}")


def try_trimesh(path: Path) -> None:
    try:
        import trimesh  # type: ignore
    except Exception as e:
        print(f"trimesh import fail: {e}")
        return
    print(f"trimesh {trimesh.__version__}")
    m = trimesh.load(path, force="scene")
    print(f"type {type(m)}")
    if hasattr(m, "bounds"):
        print(f"bounds {m.bounds}")
        print(f"extents {m.extents}")
    if hasattr(m, "geometry"):
        for name, g in m.geometry.items():
            verts = len(g.vertices) if hasattr(g, "vertices") else "?"
            print(f"  geom {name}: bounds={g.bounds} extents={g.extents} verts={verts}")
    try:
        dump = m.dump(concatenate=True)
        print(f"concat bounds {dump.bounds} extents {dump.extents}")
    except Exception as e:
        print(f"concat fail {e}")


def main() -> int:
    for p in PATHS:
        if not p.is_file():
            print(f"MISSING {p}")
            continue
        peek_header(p)
        try:
            g = glb_json(p)
            walk_world_bounds(g)
        except Exception as e:
            print(f"glb json parse fail: {e}")
        try_trimesh(p)
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
