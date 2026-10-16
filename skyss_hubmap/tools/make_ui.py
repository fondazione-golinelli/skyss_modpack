#!/usr/bin/env python3
"""Draws the pixel-art textures of the HUB map: the board behind the form,
buttons, place badges and the player arrow.

Same look as the skyss_minigames menus (whose drawing helpers are reused from
../skyss_minigames/tools/make_ui.py). The layout is in formspec units (15 px
each) and is also written to src/layout.lua, so the Lua code places text and
buttons exactly on the drawn panels.

Run from anywhere: python3 tools/make_ui.py
"""
import importlib.util
import math
import os
import random
import shutil
import sys
import tempfile

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, "..", "textures")
LAYOUT_LUA = os.path.join(HERE, "..", "src", "layout.lua")
PREFIX = "skyss_hubmap_"

spec = importlib.util.spec_from_file_location(
    "mg_ui", os.path.join(HERE, "..", "..", "skyss_minigames", "tools", "make_ui.py"))
mg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mg)
px = mg.px

# ── Layout (formspec units) ──────────────────────────────────────────────

W, H = 17, 11.8
GRASS_H = 0.6
SIDE_X, SIDE_W = 9.75, 6.4
TAB_W, TAB_STEP = 1.22, 1.295
LAYOUT = {
    "size": (W, H),
    "icon": (0.85, 1.08, 1.3),
    "plaque": (2.35, 1.12, 12.9, 0.95),
    "close": (15.75, 1.2, 0.7, 0.7),
    "map": (0.95, 2.55, 8.2, 8.2),          # the map image itself
    "tabs": [(SIDE_X + i * TAB_STEP, 2.35, TAB_W, 0.8) for i in range(5)],
    "list": (SIDE_X, 3.35, SIDE_W, 4.95),
    "detail": (SIDE_X, 8.5, SIDE_W, 2.45),
}


def map_frame(d, x, y, w, h, rng):
    """Wooden frame around the map, 0.2 units wide."""
    mg.wood_frame(d, x - 0.2, y - 0.2, w + 0.4, h + 0.4, rng, t=0.2)


def draw_board():
    rng = random.Random("hubmap")
    img = Image.new("RGBA", (px(W), px(H)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    fx, fy = mg.FRAME
    frame = (fx, fy, W - 2 * fx, H - fy - GRASS_H + 0.15)
    mg.ropes(d, (2.0, W - 2.0), 0.45, fy + 0.1)
    inner = mg.wood_frame(d, *frame, rng)
    mg.parchment(img, d, *inner, rng)
    mg.foliage_beam(d, W, rng)
    mg.icon_frame(d, *LAYOUT["icon"])
    mg.plaque(d, *LAYOUT["plaque"], rng)
    map_frame(d, *LAYOUT["map"], rng)
    for tab in LAYOUT["tabs"]:
        mg.plaque(d, *tab, rng)
    mg.panel(d, *LAYOUT["list"])
    mg.panel(d, *LAYOUT["detail"])
    mg.grass(d, W, H - GRASS_H, GRASS_H, rng)
    img.save(os.path.join(TEX, PREFIX + "ui_board.png"))


def reuse_minigame_art():
    """Buttons and the close button, drawn by the minigames script under our names."""
    tmp = tempfile.mkdtemp()
    try:
        mg.TEX = tmp
        for name in ("green", "blue", "wood"):
            for state in ("normal", "hover", "pressed"):
                mg.button(name, mg.BUTTONS[name], state)
        mg.close_button()
        for f in os.listdir(tmp):
            shutil.move(os.path.join(tmp, f), os.path.join(TEX, f.replace("skyss_minigames_", PREFIX, 1)))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# ── Badges: one per tag, a coloured disc with a light glyph ───────────────

LIGHT = (249, 243, 223)
TAGS = {
    "all": (138, 98, 56),
    "spawn": (214, 160, 40),
    "portal": (128, 72, 196),
    "minigames": (63, 140, 60),
    "countries": (55, 112, 178),
}
FLAG_COLOURS = {"red": (200, 46, 40), "white": (244, 244, 244), "green": (40, 140, 64),
                "yellow": (246, 202, 40), "black": (34, 30, 30)}
FLAGS = {  # rows top -> bottom, as in hubgen
    "it": [["green", "white", "red"]],
    "es": [["red"], ["yellow"], ["yellow"], ["red"]],
    "de": [["black"], ["red"], ["yellow"]],
    "hu": [["red"], ["white"], ["green"]],
    "pl": [["white"], ["red"]],
}


def disc(colour, size=16):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, size - 1, size - 1], fill=mg.shade(colour, 0.55))
    d.ellipse([1, 1, size - 2, size - 2], fill=colour)
    d.ellipse([3, 2, 7, 5], fill=mg.shade(colour, 1.2))
    return img, d


def glyph_spawn(d):
    # a little house
    d.polygon([(8, 3), (3, 8), (13, 8)], fill=LIGHT)
    d.rectangle([4, 8, 11, 12], fill=LIGHT)
    d.rectangle([7, 10, 8, 12], fill=TAGS["spawn"])


def glyph_portal(d):
    # obsidian-like arch with a glowing inside
    d.rectangle([4, 3, 11, 12], fill=(40, 24, 60))
    d.rectangle([5, 4, 10, 12], fill=(210, 150, 255))
    d.rectangle([6, 5, 9, 12], fill=(170, 100, 240))


def glyph_minigames(d):
    # trophy
    d.rectangle([5, 3, 10, 4], fill=LIGHT)
    d.rectangle([5, 5, 10, 7], fill=LIGHT)
    d.point((4, 4), fill=LIGHT)
    d.point((11, 4), fill=LIGHT)
    d.rectangle([7, 8, 8, 10], fill=LIGHT)
    d.rectangle([5, 11, 10, 12], fill=LIGHT)


def glyph_countries(d):
    # flag on a pole
    d.line([4, 3, 4, 13], fill=LIGHT)
    d.rectangle([5, 3, 11, 8], fill=LIGHT)


def glyph_all(d):
    for x, y in ((4, 4), (9, 4), (4, 9), (9, 9)):
        d.rectangle([x, y, x + 2, y + 2], fill=LIGHT)


def badges():
    glyphs = {"all": glyph_all, "spawn": glyph_spawn, "portal": glyph_portal,
              "minigames": glyph_minigames, "countries": glyph_countries}
    for tag, colour in TAGS.items():
        img, d = disc(colour)
        glyphs[tag](d)
        img.save(os.path.join(TEX, f"{PREFIX}tag_{tag}.png"))
    # empty disc for minigames, the game's own icon is drawn on top
    img, _ = disc(TAGS["minigames"])
    img.save(os.path.join(TEX, PREFIX + "pin_minigames.png"))


def flags():
    """Country badges: the flag on a blue disc, and the plain flag for lists."""
    for code, rows in FLAGS.items():
        flag = Image.new("RGBA", (12, 8), (0, 0, 0, 0))
        fd = ImageDraw.Draw(flag)
        for r, row in enumerate(rows):
            for c, colour in enumerate(row):
                x0, x1 = c * 12 // len(row), (c + 1) * 12 // len(row) - 1
                y0, y1 = r * 8 // len(rows), (r + 1) * 8 // len(rows) - 1
                fd.rectangle([x0, y0, x1, y1], fill=FLAG_COLOURS[colour])
        img, d = disc(TAGS["countries"])
        d.rectangle([1, 3, 14, 12], fill=(34, 30, 30))
        img.paste(flag, (2, 4))
        img.save(os.path.join(TEX, f"{PREFIX}flag_{code}.png"))


def selection_ring():
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, 23, 23], outline=(48, 44, 46), width=2)
    d.ellipse([2, 2, 21, 21], outline=(255, 230, 120), width=2)
    img.save(os.path.join(TEX, PREFIX + "selected.png"))


def arrows():
    """The player on the map, pointing where they look: 8 directions,
    counter-clockwise from north like the Luanti yaw."""
    for k in range(8):
        img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        a = math.radians(k * 45)

        def rot(x, y):
            # x right, y up (north); counter-clockwise by a
            rx = x * math.cos(a) - y * math.sin(a)
            ry = x * math.sin(a) + y * math.cos(a)
            return 32 + rx, 32 - ry

        outer = [rot(0, 26), rot(18, -20), rot(0, -10), rot(-18, -20)]
        inner = [rot(0, 18), rot(11, -13), rot(0, -6), rot(-11, -13)]
        d.polygon(outer, fill=(48, 44, 46))
        d.polygon(inner, fill=(255, 255, 255))
        img = img.resize((16, 16), Image.LANCZOS)
        img.save(os.path.join(TEX, f"{PREFIX}me_{k}.png"))


def map_item():
    """Inventory image: a folded parchment map with a pin."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(1, 3), (5, 1), (10, 3), (15, 1), (15, 13), (10, 15), (5, 13), (1, 15)], fill=mg.WOOD_DARK)
    d.polygon([(2, 4), (5, 2), (10, 4), (14, 2), (14, 12), (10, 14), (5, 12), (2, 14)], fill=mg.PARCH)
    d.line([5, 3, 5, 12], fill=mg.SPECK)
    d.line([10, 4, 10, 13], fill=mg.SPECK)
    d.ellipse([3, 6, 9, 11], fill=(110, 170, 80))
    d.line([8, 11, 13, 6], fill=(58, 110, 190))
    d.ellipse([9, 3, 13, 7], fill=(192, 80, 63))
    d.point((11, 8), fill=(192, 80, 63))
    img.save(os.path.join(TEX, PREFIX + "item.png"))


def lua_value(v):
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{k} = {lua_value(x)}" for k, x in v.items()) + " }"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_value(x) for x in v) + " }"
    return repr(v)


def write_layout():
    os.makedirs(os.path.dirname(LAYOUT_LUA), exist_ok=True)
    with open(LAYOUT_LUA, "w") as f:
        f.write("-- Generated by tools/make_ui.py: positions of the panels drawn in\n")
        f.write("-- skyss_hubmap_ui_board.png, in formspec units. Do not edit.\n")
        f.write(f"return {lua_value(LAYOUT)}\n")


if __name__ == "__main__":
    os.makedirs(TEX, exist_ok=True)
    draw_board()
    reuse_minigame_art()
    badges()
    flags()
    selection_ring()
    arrows()
    map_item()
    write_layout()
    print("done")
    sys.exit(0)
