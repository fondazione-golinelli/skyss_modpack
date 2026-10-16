#!/usr/bin/env python3
"""Renders the HUB island for the map form: textures/skyss_hubmap_map.png.

Uses the renderer of classrooms_bridge (tools/render_maps.py) on a hub world
and keeps only the hub island, X and Z from MIN to MAX (the same bounds as
BOUNDS in init.lua). The image is doubled with nearest-neighbour scaling so
it stays sharp in the form.

Usage (needs numpy and Pillow; zstandard only for blocks Luanti re-saved):

  python3 tools/make_map.py ../../templates/hub/.luanti/worlds/world
"""
import importlib.util
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "textures", "skyss_hubmap_map.png")
MIN, MAX = -170, 169
SCALE = 2

spec = importlib.util.spec_from_file_location(
    "render_maps", os.path.join(HERE, "..", "..", "classrooms_bridge", "tools", "render_maps.py"))
rm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rm)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    image, bounds, skipped = rm.render(sys.argv[1], 100000)
    if skipped:
        print(f"warning: {skipped} map blocks skipped (install zstandard)")
    # column 0 = bounds min_x, row 0 = bounds max_z
    left = MIN - bounds["min_x"]
    top = bounds["max_z"] - MAX
    size = MAX - MIN + 1
    crop = image.convert("RGB").crop((left, top, left + size, top + size))
    crop = crop.resize((size * SCALE, size * SCALE), Image.NEAREST)
    crop.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(OUT, optimize=True)
    print(f"{OUT}: X/Z {MIN}..{MAX}")


if __name__ == "__main__":
    main()
