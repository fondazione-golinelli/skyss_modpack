#!/usr/bin/env python3
"""Draws the textures of the teacher guide.

Writes into ../textures:
  classrooms_bridge_guide.png              the guide item (a handbook)
  classrooms_bridge_guide_tool_<name>.png  World Tools tiles and map icons,
  classrooms_bridge_guide_map_<name>.png   copied from the classrooms proxy
                                           plugin's icons, so the guide can
                                           show them

Run: python3 tools/make_guide.py
"""
import os
import shutil

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "textures")
PROXY_ICONS = os.path.join(HERE, "..", "..", "..", "proxy-plugins",
                           "mt-multiserver-proxy-classrooms", "icons")


def hexcolor(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def from_ascii(rows, palette):
    assert len(rows) == 16, len(rows)
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == 16, (y, row)
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), palette[ch])
    return img


# A blue handbook with pages on the right, a gold "?" and a red bookmark.
GUIDE = from_ascii([
    "................",
    "..kkkkkkkkkkk...",
    ".kbbbbbbbbbbwk..",
    ".kblllllllbbwwk.",
    ".kbbbbbbbbbbwwk.",
    ".kbbbyyyybbbwwk.",
    ".kbbyybbyybbwwk.",
    ".kbbbbbbyybbwwk.",
    ".kbbbbbyybbbwwk.",
    ".kbbbbyybbbbwwk.",
    ".kbbbbbbbbbbwwk.",
    ".kbbbbyybbbbwwk.",
    ".kddddddddddwwk.",
    ".kddrdddddddwk..",
    "..kkrkkkkkkkk...",
    "....r...........",
], {
    "k": hexcolor("#13203a"),
    "b": hexcolor("#2f6fd0"),
    "l": hexcolor("#6fa3f0"),
    "d": hexcolor("#1f4e9a"),
    "w": hexcolor("#efe6cf"),
    "y": hexcolor("#ffd43b"),
    "r": hexcolor("#e94560"),
})


def main():
    GUIDE.save(os.path.join(OUT, "classrooms_bridge_guide.png"))
    for name in ("zones", "map", "time", "rules", "settings"):
        shutil.copyfile(os.path.join(PROXY_ICONS, "tool_" + name + ".png"),
                        os.path.join(OUT, "classrooms_bridge_guide_tool_" + name + ".png"))
    for name in ("flat", "generic", "italy", "europe", "moon", "mars"):
        shutil.copyfile(os.path.join(PROXY_ICONS, name + ".png"),
                        os.path.join(OUT, "classrooms_bridge_guide_map_" + name + ".png"))


if __name__ == "__main__":
    main()
