#!/usr/bin/env python3
"""Generate the Forest Restoration pixel-art textures.

Run from anywhere:  python3 tools/gen_assets.py
Outputs go to ../textures (relative to this script). Everything is drawn
here, pixel by pixel, in the palette of the other Skyss minigames: 32x32
item icons, 16x16 HUD icons and node textures, small particles.
"""
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEXTURES = os.path.join(ROOT, "textures")
PREFIX = "skyss_treegame_"


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (c[3],)


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def save(im, name):
    os.makedirs(TEXTURES, exist_ok=True)
    im.save(os.path.join(TEXTURES, PREFIX + name + ".png"), optimize=True)


def outline(im, color=hexc("#1c140c")):
    """1 px dark outline around every opaque shape, like the other icons."""
    w, h = im.size
    src = im.copy()
    for x in range(w):
        for y in range(h):
            if src.getpixel((x, y))[3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny))[3] > 0:
                    im.putpixel((x, y), color)
                    break
    return im


def put(im, pts, color):
    for p in pts:
        im.putpixel(p, color)


# ---------------------------------------------------------------- palette

SOIL = hexc("#6b4a2b")
SOIL_D = hexc("#4a3019")
COMPOST = hexc("#3a2a1a")
SACK = hexc("#c9a46a")
LEAF = hexc("#5fbf4a")
LEAF_D = hexc("#3d8a34")
LEAF_L = hexc("#9be26f")
WATER = hexc("#4fa8ff")
WATER_D = hexc("#2f6fd0")
WATER_L = hexc("#bfe4ff")
METAL = hexc("#3f9ba0")
METAL_D = hexc("#2b6c70")
METAL_L = hexc("#8fd8d8")
WOOD = hexc("#9a6a3a")
WOOD_D = hexc("#6b4524")
BARK = hexc("#7a5230")


# ---------------------------------------------------------------- items

def compost_bag():
    """A burlap sack, open at the top and full of dark compost, leaf label."""
    rng = random.Random(3)
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    # body
    d.polygon([(8, 10), (24, 10), (27, 27), (25, 29), (7, 29), (5, 27)], fill=SACK)
    for y in range(10, 30):
        for x in range(4, 28):
            c = im.getpixel((x, y))
            if c[3]:
                k = rng.choice((0.92, 0.97, 1.0, 1.0, 1.04))
                if (x + y) % 4 == 0:
                    k *= 0.93
                if x > 20:
                    k *= 0.88
                im.putpixel((x, y), shade(c, k))
    # rolled rim
    d.rectangle((7, 8, 25, 10), fill=shade(SACK, 0.8))
    d.line((7, 8, 25, 8), fill=shade(SACK, 1.1))
    # compost heap at the top
    d.ellipse((8, 3, 24, 11), fill=COMPOST)
    for _ in range(26):
        x, y = rng.randint(10, 22), rng.randint(4, 9)
        if im.getpixel((x, y))[:3] == COMPOST[:3]:
            im.putpixel((x, y), rng.choice((SOIL, SOIL_D, hexc("#5a3d22"))))
    put(im, [(12, 5), (19, 6), (15, 4)], LEAF_D)
    # label: a green leaf
    d.ellipse((11, 15, 21, 25), fill=hexc("#efe2c0"))
    d.polygon([(13, 23), (14, 18), (17, 16), (20, 17), (19, 21), (16, 23)], fill=LEAF)
    d.line((13, 23, 18, 18), fill=LEAF_D)
    put(im, [(18, 17), (19, 18)], LEAF_L)
    return outline(im)


def watering_can():
    """A teal metal can with a long spout and a rose, water dripping."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    # body
    d.rectangle((9, 13, 22, 27), fill=METAL)
    d.rectangle((9, 13, 11, 27), fill=METAL_L)
    d.rectangle((20, 13, 22, 27), fill=METAL_D)
    d.rectangle((9, 26, 22, 27), fill=METAL_D)
    d.line((9, 13, 22, 13), fill=METAL_L)
    # band
    d.rectangle((9, 18, 22, 19), fill=METAL_D)
    # handle
    d.arc((11, 4, 26, 20), 180, 360, fill=METAL_D, width=2)
    d.line((22, 12, 25, 12), fill=METAL_D, width=2)
    # spout
    d.line((10, 23, 3, 13), fill=METAL, width=3)
    d.line((10, 22, 3, 12), fill=METAL_L)
    # rose
    d.rectangle((1, 10, 4, 13), fill=METAL_D)
    put(im, [(1, 10), (3, 10)], METAL_L)
    # drops
    put(im, [(1, 16), (1, 17), (3, 19), (3, 20), (0, 22)], WATER)
    put(im, [(1, 16), (3, 19)], WATER_L)
    return outline(im)


def seeds():
    """A paper seed packet with wildflowers on the front, seeds spilling out."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    paper = hexc("#f4e7c4")
    # packet, slightly tilted top edge torn open
    d.polygon([(6, 6), (24, 4), (26, 28), (8, 30)], fill=paper)
    d.line((24, 4, 26, 28), fill=shade(paper, 0.82))
    d.line((26, 28, 8, 30), fill=shade(paper, 0.82))
    put(im, [(9, 6), (12, 5), (15, 6), (18, 5), (21, 5)], shade(paper, 0.85))
    # picture frame
    d.polygon([(9, 10), (23, 9), (24, 23), (10, 24)], fill=hexc("#bfe4ff"))
    d.polygon([(10, 19), (24, 18), (24, 23), (10, 24)], fill=LEAF)
    # stems and flowers
    for x0, y0, x1 in ((13, 20, 12), (17, 19, 18), (21, 19, 21)):
        d.line((x0, y0, x1, y0 - 6), fill=LEAF_D)
    for (x, y, c) in ((12, 13, "#ff7aa8"), (18, 12, "#ffd43b"), (21, 14, "#7a8cff")):
        d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=hexc(c))
        im.putpixel((x, y), hexc("#fff3b0"))
    put(im, [(11, 21), (15, 20), (20, 21), (23, 20)], LEAF_L)
    # label stripe
    d.line((10, 26, 24, 25), fill=hexc("#c0623a"), width=2)
    # seeds spilling from the top
    for (x, y) in ((14, 1), (17, 2), (20, 0), (11, 2), (22, 2)):
        put(im, [(x, y), (x + 1, y)], hexc("#7a5a2a"))
    return outline(im)


def sapling():
    """A young sapling in a ball of soil, the way nurseries sell them."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    # soil ball wrapped in burlap
    d.ellipse((8, 20, 24, 30), fill=SACK)
    d.ellipse((8, 20, 24, 24), fill=SOIL)
    d.line((9, 25, 23, 25), fill=shade(SACK, 0.8))
    put(im, [(12, 27), (16, 28), (20, 27)], shade(SACK, 0.85))
    # stem
    d.line((16, 22, 16, 9), fill=BARK, width=2)
    d.line((16, 15, 11, 11), fill=BARK)
    d.line((17, 13, 21, 9), fill=BARK)
    # leaves
    for (x0, y0, x1, y1) in ((6, 6, 13, 12), (18, 4, 25, 10), (12, 2, 20, 9), (19, 11, 25, 16), (7, 13, 12, 17)):
        d.ellipse((x0, y0, x1, y1), fill=LEAF)
    for (x0, y0, x1, y1) in ((8, 7, 10, 9), (20, 5, 22, 7), (14, 3, 16, 5)):
        d.rectangle((x0, y0, x1, y1), fill=LEAF_L)
    put(im, [(11, 11), (12, 10), (23, 9), (24, 8), (18, 8), (19, 7), (24, 15), (11, 16)], LEAF_D)
    return outline(im)


def game_icon():
    """Launcher menu icon: a sapling sprouting from a green block, a drop."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    # block, seen from the front with its top
    d.polygon([(4, 18), (16, 13), (28, 18), (16, 23)], fill=LEAF)
    d.polygon([(4, 18), (16, 23), (16, 31), (4, 26)], fill=SOIL)
    d.polygon([(16, 23), (28, 18), (28, 26), (16, 31)], fill=SOIL_D)
    d.polygon([(4, 18), (16, 23), (16, 25), (4, 20)], fill=LEAF_D)
    d.polygon([(16, 23), (28, 18), (28, 20), (16, 25)], fill=shade(LEAF_D, 0.8))
    put(im, [(8, 18), (12, 16), (20, 16), (23, 19), (15, 20)], LEAF_L)
    # sprout
    d.line((16, 18, 16, 8), fill=BARK, width=2)
    d.ellipse((8, 4, 16, 10), fill=LEAF)
    d.ellipse((16, 2, 25, 9), fill=LEAF)
    put(im, [(10, 6), (11, 5), (19, 4), (20, 4)], LEAF_L)
    # water drop
    d.polygon([(26, 3), (28, 7), (24, 7)], fill=WATER)
    d.ellipse((24, 6, 28, 10), fill=WATER)
    put(im, [(25, 7)], WATER_L)
    return outline(im)


# ---------------------------------------------------------------- HUD icons (16x16)

def hud_soil():
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    d.polygon([(1, 5), (8, 2), (15, 5), (8, 8)], fill=LEAF)
    d.polygon([(1, 5), (8, 8), (8, 15), (1, 12)], fill=SOIL)
    d.polygon([(8, 8), (15, 5), (15, 12), (8, 15)], fill=SOIL_D)
    d.polygon([(1, 5), (8, 8), (8, 9), (1, 6)], fill=LEAF_D)
    d.polygon([(8, 8), (15, 5), (15, 6), (8, 9)], fill=shade(LEAF_D, 0.8))
    put(im, [(5, 4), (10, 4), (8, 6)], LEAF_L)
    return outline(im)


def hud_plant():
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    d.line((8, 14, 8, 7), fill=LEAF_D)
    d.line((8, 12, 4, 9), fill=LEAF)
    d.line((8, 11, 12, 8), fill=LEAF)
    petal = hexc("#ff7aa8")
    for (x, y) in ((8, 2), (5, 5), (11, 5), (6, 8), (10, 8)):
        d.ellipse((x - 2, y - 2, x + 1, y + 1), fill=petal)
    d.rectangle((7, 4, 9, 6), fill=hexc("#ffd43b"))
    put(im, [(3, 14), (12, 14), (5, 15), (10, 15)], LEAF)
    return outline(im)


def hud_tree():
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle((7, 9, 9, 15), fill=BARK)
    d.line((7, 9, 7, 15), fill=shade(BARK, 1.2))
    d.ellipse((1, 1, 15, 12), fill=LEAF)
    d.ellipse((4, 2, 9, 6), fill=LEAF_L)
    put(im, [(11, 8), (12, 9), (4, 9), (13, 6)], LEAF_D)
    return outline(im)


def hud_water():
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    d.polygon([(8, 1), (12, 8), (4, 8)], fill=WATER)
    d.ellipse((3, 5, 13, 15), fill=WATER)
    d.ellipse((5, 8, 7, 11), fill=WATER_L)
    put(im, [(10, 13), (11, 12)], WATER_D)
    return outline(im)


def hud_water_empty():
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    d.polygon([(8, 1), (12, 8), (4, 8)], fill=hexc("#3a4a58"))
    d.ellipse((3, 5, 13, 15), fill=hexc("#3a4a58"))
    return outline(im)


# ---------------------------------------------------------------- nodes (16x16)

def fertile_overlay():
    """Drawn over default_dirt.png: dark compost crumbs and tiny sprouts."""
    rng = random.Random(11)
    im = img(16, 16)
    for _ in range(34):
        x, y = rng.randrange(16), rng.randrange(16)
        im.putpixel((x, y), rng.choice((COMPOST, hexc("#2c1f12"), hexc("#4b3420", 220))))
    for (x, y) in ((3, 4), (11, 2), (7, 10), (13, 12), (2, 13)):
        im.putpixel((x, y), LEAF)
        im.putpixel((x, y - 1), LEAF_L)
    return im


def barrel():
    """Rain barrel: wooden staves with iron hoops, water on the top."""
    rng = random.Random(5)
    side = img(16, 16)
    for x in range(16):
        stave = WOOD if (x // 3) % 2 == 0 else shade(WOOD, 0.9)
        for y in range(16):
            side.putpixel((x, y), shade(stave, rng.choice((0.95, 1.0, 1.0, 1.05))))
        side.putpixel((x, 0), shade(WOOD, 1.15))
    for x in range(0, 16, 3):
        for y in range(16):
            side.putpixel((x, y), WOOD_D)
    hoop = hexc("#5a5f66")
    for y in (2, 3, 12, 13):
        for x in range(16):
            side.putpixel((x, y), hoop if y in (2, 12) else shade(hoop, 0.75))
    # a little water drop sign
    d = ImageDraw.Draw(side)
    d.polygon([(8, 5), (10, 8), (6, 8)], fill=WATER)
    d.ellipse((6, 7, 10, 10), fill=WATER)
    side.putpixel((7, 8), WATER_L)
    save(side, "barrel_side")

    top = img(16, 16)
    d = ImageDraw.Draw(top)
    d.rectangle((0, 0, 15, 15), fill=WOOD_D)
    d.rectangle((1, 1, 14, 14), fill=WOOD)
    d.rectangle((2, 2, 13, 13), fill=WATER_D)
    d.rectangle((3, 3, 12, 12), fill=WATER)
    put(top, [(5, 5), (6, 5), (9, 8), (10, 8), (5, 10)], WATER_L)
    save(top, "barrel_top")

    bottom = img(16, 16)
    d = ImageDraw.Draw(bottom)
    d.rectangle((0, 0, 15, 15), fill=WOOD_D)
    d.rectangle((1, 1, 14, 14), fill=shade(WOOD, 0.85))
    save(bottom, "barrel_bottom")


# ---------------------------------------------------------------- particles

def particles():
    im = img(4, 6)
    d = ImageDraw.Draw(im)
    d.polygon([(1, 0), (3, 3), (0, 3)], fill=WATER)
    d.ellipse((0, 2, 3, 5), fill=WATER)
    im.putpixel((1, 3), WATER_L)
    save(im, "drop")

    im = img(3, 3)
    put(im, [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)], COMPOST)
    im.putpixel((1, 1), SOIL)
    save(im, "crumb")

    im = img(2, 3)
    put(im, [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2)], hexc("#7a5a2a"))
    im.putpixel((1, 0), hexc("#a8844a"))
    save(im, "seed")

    im = img(5, 5)
    put(im, [(2, 0), (1, 1), (2, 1), (3, 1), (0, 2), (1, 2), (2, 2), (3, 2), (1, 3), (2, 3), (2, 4)], LEAF)
    put(im, [(2, 1), (2, 2)], LEAF_L)
    save(im, "leaf")

    # white sparkle, tinted with [multiply in the mod
    im = img(7, 7)
    w = (255, 255, 255, 255)
    put(im, [(3, 0), (3, 1), (3, 5), (3, 6), (0, 3), (1, 3), (5, 3), (6, 3)], (255, 255, 255, 180))
    put(im, [(2, 2), (4, 2), (2, 4), (4, 4)], (255, 255, 255, 120))
    put(im, [(3, 2), (2, 3), (3, 3), (4, 3), (3, 4)], w)
    save(im, "sparkle")


def main():
    save(compost_bag(), "compost")
    save(watering_can(), "watering_can")
    save(seeds(), "seeds")
    save(sapling(), "sapling")
    save(game_icon(), "icon")
    save(hud_soil(), "hud_soil")
    save(hud_plant(), "hud_plant")
    save(hud_tree(), "hud_tree")
    save(hud_water(), "hud_water")
    save(hud_water_empty(), "hud_water_empty")
    save(fertile_overlay(), "fertile_overlay")
    barrel()
    particles()
    print("textures written to", TEXTURES)


if __name__ == "__main__":
    main()
