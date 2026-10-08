#!/usr/bin/env python3
"""Render top-down maps of the instance templates for the classrooms map.

For each template world it reads `map.sqlite` (read-only), finds the highest
"ground" node of every column (ignoring low vegetation), colours it by
material, adds hill shading, and writes:

  textures/classrooms_bridge_map_<template>.png   (at most --size pixels)
  maps.lua                                         (bounds per template)

The classrooms_bridge mod picks the map of its world from the
INSTANCE_TEMPLATE_NAME environment variable set by the classrooms plugin.

Usage (needs numpy, Pillow; zstandard only for blocks Luanti re-saved):

  python3 tools/render_maps.py /path/to/development/addons/templates
  python3 tools/render_maps.py TEMPLATES --only poland --size 2048
"""

import argparse
import os
import sqlite3
import struct
import sys
import zlib

import numpy as np
from PIL import Image

try:
    import zstandard
except ImportError:  # v29 blocks are skipped without it
    zstandard = None

MOD_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BS = 16

SKIP_EXACT = {"air", "ignore", "mcl_core:snow"}
SKIP_PARTS = ("tallgrass", "fern", "flower", "sapling", "deadbush", "double_", "mushroom",
              "torch", "reeds", "sweet_berry", "vine", "lily", "seagrass", "kelp", "button",
              "pressure_plate", "rail", "carpet", "sign", "lever")

COLORS = [
    ("water", (52, 98, 182)),
    ("ice", (166, 202, 240)),
    ("snow", (238, 243, 248)),
    ("redsand", (190, 108, 52)),
    ("sandstone", (214, 200, 150)),
    ("sand", (222, 210, 166)),
    ("gravel", (138, 133, 128)),
    ("hardened_clay", (160, 92, 62)),
    ("clay", (158, 164, 178)),
    ("dirt_with_grass", (96, 146, 62)),
    ("grass", (96, 146, 62)),
    ("podzol", (112, 86, 50)),
    ("mycelium", (112, 96, 112)),
    ("farmland", (112, 80, 48)),
    ("soil", (112, 80, 48)),
    ("leaves", (52, 98, 42)),
    ("tree", (98, 74, 44)),
    ("log", (98, 74, 44)),
    ("wood", (164, 124, 74)),
    ("planks", (164, 124, 74)),
    ("dirt", (122, 88, 56)),
    ("bedrock", (60, 60, 60)),
    ("stone", (126, 126, 126)),
    ("cobble", (118, 118, 118)),
    ("andesite", (130, 131, 131)),
    ("diorite", (190, 190, 190)),
    ("granite", (150, 106, 90)),
    ("glass", (190, 220, 230)),
    ("wool", (220, 220, 220)),
    ("brick", (150, 80, 60)),
]


def is_ground(name):
    if name in SKIP_EXACT:
        return False
    local = name.split(":")[-1]
    return not any(part in local for part in SKIP_PARTS)


def color_of(name):
    local = name.split(":")[-1]
    for part, rgb in COLORS:
        if part in local:
            return rgb
    h = zlib.crc32(name.encode())
    return (110 + h % 60, 110 + (h >> 8) % 60, 110 + (h >> 16) % 60)


def _read_name_map(buf, off):
    _ver, count = struct.unpack_from(">BH", buf, off)
    off += 3
    names = {}
    for _ in range(count):
        nid, ln = struct.unpack_from(">HH", buf, off)
        off += 4
        names[nid] = buf[off:off + ln].decode("utf-8", "replace")
        off += ln
    return names, off


def decode_block(data):
    """Return (param0 array [z][y][x], {id: name}) or None."""
    ver = data[0]
    if ver == 29:
        if zstandard is None:
            return None
        buf = zstandard.ZstdDecompressor().decompressobj().decompress(data[1:])
        off = 1 + 2 + 4  # flags, lighting_complete, timestamp
        names, off = _read_name_map(buf, off)
        off += 2  # content_width, params_width
        p0 = np.frombuffer(buf, dtype=">u2", count=4096, offset=off)
        return p0.reshape(BS, BS, BS), names
    if 25 <= ver <= 28:
        d = zlib.decompressobj()
        nodes = d.decompress(data[4:])
        rest = d.unused_data
        d2 = zlib.decompressobj()  # node metadata
        d2.decompress(rest)
        rest = d2.unused_data
        off = 0
        _sver, count = struct.unpack_from(">BH", rest, off)
        off += 3
        for _ in range(count):  # static objects
            off += 1 + 12
            (ln,) = struct.unpack_from(">H", rest, off)
            off += 2 + ln
        off += 4  # timestamp
        names, _ = _read_name_map(rest, off)
        p0 = np.frombuffer(nodes, dtype=">u2", count=4096)
        return p0.reshape(BS, BS, BS), names
    return None


def render(world, size):
    db = sqlite3.connect(f"file:{os.path.join(world, 'map.sqlite')}?mode=ro", uri=True)
    min_bx, max_bx, min_bz, max_bz = db.execute(
        "SELECT min(x), max(x), min(z), max(z) FROM blocks").fetchone()
    w = (max_bx - min_bx + 1) * BS
    d = (max_bz - min_bz + 1) * BS
    height = np.full((d, w), -32768, dtype=np.int32)
    colors = np.zeros((d, w, 3), dtype=np.uint8)
    water = np.zeros((d, w), dtype=bool)

    name_ids = {}        # name -> global id
    lut_ground, lut_color, lut_water = [], [], []

    def gid(name):
        if name not in name_ids:
            name_ids[name] = len(lut_ground)
            lut_ground.append(is_ground(name))
            lut_color.append(color_of(name))
            lut_water.append("water" in name)
        return name_ids[name]

    skipped = 0
    cur, filled = None, None
    rows = db.execute("SELECT x, z, y, data FROM blocks ORDER BY x, z, y DESC")
    for bx, bz, by, data in rows:
        if (bx, bz) != cur:
            cur, filled = (bx, bz), np.zeros((BS, BS), dtype=bool)
        if filled.all():
            continue
        decoded = decode_block(data)
        if decoded is None:
            skipped += 1
            continue
        p0, names = decoded
        local_to_global = np.zeros(max(names) + 1 if names else 1, dtype=np.int32)
        for nid, name in names.items():
            local_to_global[nid] = gid(name)
        ids = local_to_global[np.minimum(p0, len(local_to_global) - 1)]   # [z][y][x]
        ground = np.array(lut_ground, dtype=bool)[ids]
        flipped = ground[:, ::-1, :]                    # top first
        has = flipped.any(axis=1)                       # [z][x]
        top = BS - 1 - flipped.argmax(axis=1)           # local y of highest ground
        new = has & ~filled
        if not new.any():
            continue
        zz, xx = np.nonzero(new)
        gz = (bz - min_bz) * BS + zz
        gx = (bx - min_bx) * BS + xx
        node = ids[zz, top[zz, xx], xx]
        height[gz, gx] = by * BS + top[zz, xx]
        colors[gz, gx] = np.array(lut_color, dtype=np.uint8)[node]
        water[gz, gx] = np.array(lut_water, dtype=bool)[node]
        filled |= new

    # Hill shading (light from the north-west), not on water.
    h = np.where(height == -32768, 0, height).astype(np.float32)
    gx = np.zeros_like(h)
    gz = np.zeros_like(h)
    gx[:, 1:-1] = h[:, 2:] - h[:, :-2]
    gz[1:-1, :] = h[2:, :] - h[:-2, :]
    shade = np.clip(1.0 - (gx - gz) * 0.07, 0.65, 1.3)
    shade[water] = 1.0
    img = np.clip(colors.astype(np.float32) * shade[..., None], 0, 255).astype(np.uint8)
    img[height == -32768] = (24, 28, 40)

    # Row 0 is the north edge (+z), column 0 the west edge (-x).
    image = Image.fromarray(np.ascontiguousarray(img[::-1, :, :]))
    scale = max(1, -(-max(w, d) // size))
    if scale > 1:
        image = image.resize((w // scale, d // scale), Image.LANCZOS)
    image = image.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    bounds = {
        "min_x": min_bx * BS, "max_x": (max_bx + 1) * BS - 1,
        "min_z": min_bz * BS, "max_z": (max_bz + 1) * BS - 1,
        "width": image.width, "height": image.height,
    }
    return image, bounds, skipped


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("templates", help="directory with one folder per instance template")
    parser.add_argument("--only", nargs="*", help="template names to render (default: all)")
    parser.add_argument("--size", type=int, default=1536, help="max texture size in pixels")
    args = parser.parse_args()

    maps = {}
    lua_path = os.path.join(MOD_DIR, "maps.lua")
    if os.path.exists(lua_path):  # keep entries of templates not rendered now
        for line in open(lua_path):
            line = line.strip()
            if line.startswith("[") and "] = {" in line:
                key = line[2:line.index('"]')]
                maps[key] = line
    for name in sorted(os.listdir(args.templates)):
        if args.only and name not in args.only:
            continue
        world = os.path.join(args.templates, name, ".luanti", "worlds", "world")
        if not os.path.exists(os.path.join(world, "map.sqlite")):
            continue
        print(f"rendering {name} ...", flush=True)
        image, b, skipped = render(world, args.size)
        out = os.path.join(MOD_DIR, "textures", f"classrooms_bridge_map_{name}.png")
        image.save(out, optimize=True)
        print(f"  {b['max_x'] - b['min_x'] + 1}x{b['max_z'] - b['min_z'] + 1} nodes -> "
              f"{b['width']}x{b['height']} px, {os.path.getsize(out) // 1024} KiB"
              + (f", {skipped} blocks skipped (install zstandard)" if skipped else ""))
        maps[name] = (f'["{name}"] = {{ min_x = {b["min_x"]}, max_x = {b["max_x"]}, '
                      f'min_z = {b["min_z"]}, max_z = {b["max_z"]}, '
                      f'width = {b["width"]}, height = {b["height"]} }},')
    with open(lua_path, "w") as f:
        f.write("-- Generated by tools/render_maps.py: bounds of each template map texture.\n")
        f.write("return {\n")
        for key in sorted(maps):
            f.write("    " + maps[key] + "\n")
        f.write("}\n")
    print("wrote", lua_path)


if __name__ == "__main__":
    sys.exit(main())
