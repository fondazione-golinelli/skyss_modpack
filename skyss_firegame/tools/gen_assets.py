#!/usr/bin/env python3
"""Generate the Wildfire Crew pixel-art textures.

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
PREFIX = "skyss_firegame_"


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

RED = hexc("#d8432f")
RED_D = hexc("#9c2a1f")
RED_L = hexc("#ff7a5c")
FLAME = hexc("#ff9a2a")
FLAME_L = hexc("#ffd43b")
WATER = hexc("#4fa8ff")
WATER_D = hexc("#2f6fd0")
WATER_L = hexc("#bfe4ff")
WOOD = hexc("#9a6a3a")
WOOD_D = hexc("#6b4524")
WOOD_L = hexc("#c08a52")
STEEL = hexc("#9aa4ad")
STEEL_D = hexc("#5f6a73")
STEEL_L = hexc("#d5dde3")
RUBBER = hexc("#2b2b2e")
CHAR = hexc("#2a2422")
ASH = hexc("#5a5550")
GREEN = hexc("#5fbf4a")
FUR = hexc("#b08a62")
FUR_L = hexc("#e2cfb2")


# ---------------------------------------------------------------- items

def flapper():
    """Fire beater: a long wooden handle with a square rubber flap."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    d.line((26, 30, 13, 13), fill=WOOD, width=3)
    d.line((27, 29, 14, 12), fill=WOOD_L)
    # metal clamp
    d.polygon([(11, 13), (15, 10), (17, 12), (13, 15)], fill=STEEL)
    # rubber flap
    d.polygon([(2, 8), (10, 2), (16, 9), (8, 16)], fill=RUBBER)
    d.line((3, 8, 10, 3), fill=hexc("#4a4a50"))
    put(im, [(6, 9), (9, 7), (11, 10), (8, 12)], hexc("#3a3a3f"))
    # a puff of smoke being beaten out
    put(im, [(2, 18), (3, 19), (5, 20), (1, 21)], hexc("#a0a0a0"))
    return outline(im)


def pump():
    """Backpack pump: a red tank with straps, a hose and a brass nozzle."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((6, 6, 20, 28), radius=3, fill=RED)
    d.rectangle((6, 8, 8, 26), fill=RED_L)
    d.rectangle((18, 8, 20, 26), fill=RED_D)
    d.rectangle((10, 3, 16, 6), fill=STEEL)  # filler cap
    d.line((10, 3, 16, 3), fill=STEEL_L)
    d.rectangle((6, 15, 20, 16), fill=RED_D)  # band
    # water level window
    d.rectangle((10, 18, 13, 25), fill=WATER)
    d.rectangle((10, 18, 13, 20), fill=WATER_L)
    # hose
    d.line((20, 24, 24, 26), fill=RUBBER, width=2)
    d.line((24, 26, 27, 20), fill=RUBBER, width=2)
    d.line((27, 20, 28, 10), fill=RUBBER, width=2)
    # brass lance
    d.line((28, 10, 30, 3), fill=hexc("#d6a83a"), width=2)
    # spray
    put(im, [(31, 0), (29, 0), (30, 1)], WATER_L)
    return outline(im)


def rake():
    """McLeod-style fire rake: long handle, wide steel head with tines."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    d.line((28, 30, 12, 10), fill=WOOD, width=3)
    d.line((29, 29, 13, 9), fill=WOOD_L)
    # head across the end of the handle
    d.polygon([(2, 9), (13, 0), (16, 3), (5, 12)], fill=STEEL)
    d.line((2, 9, 13, 0), fill=STEEL_L)
    for i in range(5):
        x, y = 4 + i * 2, 11 - i * 2
        d.line((x, y, x - 2, y + 3), fill=STEEL_D, width=1)
    # dirt the rake turned
    put(im, [(1, 20), (3, 21), (5, 20), (2, 22), (6, 22)], hexc("#6b4a2b"))
    return outline(im)


def carrier():
    """Pet carrier: a crate with a grid door and a handle, a bunny inside."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    body = hexc("#4f9fd8")
    d.rounded_rectangle((3, 10, 29, 29), radius=3, fill=body)
    d.rectangle((3, 26, 29, 29), fill=shade(body, 0.75))
    d.line((4, 11, 28, 11), fill=shade(body, 1.2))
    # handle
    d.rounded_rectangle((11, 4, 21, 11), radius=3, outline=shade(body, 0.7), width=2)
    # door with bars
    d.rectangle((8, 14, 24, 25), fill=hexc("#1f3b52"))
    # bunny face behind the door
    d.ellipse((11, 17, 21, 25), fill=FUR_L)
    d.line((13, 17, 12, 12), fill=FUR_L, width=2)
    d.line((19, 17, 20, 12), fill=FUR_L, width=2)
    put(im, [(14, 20), (18, 20)], hexc("#1c140c"))
    put(im, [(16, 22)], hexc("#e07a8a"))
    for x in range(9, 24, 3):
        d.line((x, 14, x, 25), fill=STEEL_L)
    d.rectangle((8, 14, 24, 25), outline=STEEL_D)
    return outline(im)


def flame_shape(d, ox, oy, s=1.0):
    pts = [(16, 2), (22, 10), (24, 18), (21, 26), (11, 26), (8, 18), (11, 12), (13, 15)]
    d.polygon([(ox + (x - 16) * s, oy + (y - 14) * s) for x, y in pts], fill=FLAME)
    inner = [(16, 10), (20, 18), (18, 25), (14, 25), (12, 19)]
    d.polygon([(ox + (x - 16) * s, oy + (y - 14) * s) for x, y in inner], fill=FLAME_L)


def game_icon():
    """Launcher icon: a flame on a small tree, with a big drop of water."""
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    # tree
    d.rectangle((9, 20, 12, 30), fill=WOOD_D)
    d.ellipse((2, 6, 19, 22), fill=GREEN)
    d.ellipse((5, 8, 11, 13), fill=hexc("#9be26f"))
    # flame on the tree
    flame_shape(d, 13, 14, 0.55)
    # drop
    d.polygon([(25, 8), (30, 18), (20, 18)], fill=WATER)
    d.ellipse((20, 14, 30, 24), fill=WATER)
    d.ellipse((22, 16, 24, 19), fill=WATER_L)
    return outline(im)


# ---------------------------------------------------------------- HUD (16x16)

def hud_fire():
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    d.polygon([(8, 0), (12, 5), (13, 10), (11, 15), (5, 15), (3, 10), (5, 6), (7, 8)], fill=FLAME)
    d.polygon([(8, 6), (10, 10), (9, 14), (7, 14), (6, 11)], fill=FLAME_L)
    return outline(im)


def hud_paw():
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    d.ellipse((4, 8, 11, 14), fill=FUR)
    for (x, y) in ((2, 6), (5, 2), (10, 2), (13, 6)):
        d.ellipse((x - 1, y - 1, x + 1, y + 2), fill=FUR)
    put(im, [(6, 10), (7, 10)], FUR_L)
    return outline(im)


def hud_burned():
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle((6, 4, 9, 14), fill=CHAR)
    d.line((6, 4, 6, 14), fill=hexc("#4a3e38"))
    d.line((9, 7, 12, 4), fill=CHAR, width=2)
    d.rectangle((1, 13, 14, 15), fill=ASH)
    put(im, [(7, 8), (8, 11)], hexc("#ff6a2a"))
    put(im, [(10, 1), (11, 0), (5, 1)], hexc("#8a8a8a"))
    return outline(im)


def hud_water(empty=False):
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    c = hexc("#3a4a58") if empty else WATER
    d.polygon([(8, 1), (12, 8), (4, 8)], fill=c)
    d.ellipse((3, 5, 13, 15), fill=c)
    if not empty:
        d.ellipse((5, 8, 7, 11), fill=WATER_L)
    return outline(im)


# ---------------------------------------------------------------- nodes (16x16)

def scorched():
    rng = random.Random(9)
    top = img(16, 16)
    for x in range(16):
        for y in range(16):
            top.putpixel((x, y), shade(ASH, rng.choice((0.7, 0.8, 0.9, 1.0, 1.1))))
    for _ in range(10):
        top.putpixel((rng.randrange(16), rng.randrange(16)), CHAR)
    for _ in range(3):
        top.putpixel((rng.randrange(16), rng.randrange(16)), hexc("#ff6a2a"))
    save(top, "scorched_top")
    side = img(16, 16)
    dirt = hexc("#6b4a2b")
    for x in range(16):
        for y in range(16):
            base = ASH if y < 3 + (x * 7 % 3) else dirt
            side.putpixel((x, y), shade(base, rng.choice((0.8, 0.9, 1.0, 1.05))))
    save(side, "scorched_side")


def charred_log():
    rng = random.Random(4)
    side = img(16, 16)
    for x in range(16):
        for y in range(16):
            k = rng.choice((0.8, 0.9, 1.0, 1.0, 1.15))
            if x % 4 == 0:
                k *= 0.7
            side.putpixel((x, y), shade(CHAR, k))
    for _ in range(5):
        x, y = rng.randrange(16), rng.randrange(16)
        side.putpixel((x, y), hexc("#ff6a2a") if rng.random() < 0.4 else hexc("#4a3e38"))
    save(side, "charred_side")
    top = img(16, 16)
    d = ImageDraw.Draw(top)
    d.rectangle((0, 0, 15, 15), fill=CHAR)
    d.ellipse((2, 2, 13, 13), fill=hexc("#3a302b"))
    d.ellipse((5, 5, 10, 10), fill=hexc("#4a3e38"))
    put(top, [(7, 7), (8, 8)], hexc("#2a2422"))
    save(top, "charred_top")


def cistern():
    """Red water tank with a tap: the pump refill station."""
    side = img(16, 16)
    d = ImageDraw.Draw(side)
    d.rectangle((0, 0, 15, 15), fill=RED)
    d.rectangle((0, 0, 1, 15), fill=RED_L)
    d.rectangle((14, 0, 15, 15), fill=RED_D)
    for y in (2, 13):
        d.line((0, y, 15, y), fill=RED_D)
    d.rectangle((5, 5, 10, 10), fill=hexc("#f4f4f4"))
    d.polygon([(8, 5), (10, 8), (6, 8)], fill=WATER)
    d.ellipse((6, 7, 10, 10), fill=WATER)
    d.rectangle((7, 11, 8, 12), fill=STEEL)
    save(side, "cistern_side")
    top = img(16, 16)
    d = ImageDraw.Draw(top)
    d.rectangle((0, 0, 15, 15), fill=RED_D)
    d.ellipse((2, 2, 13, 13), fill=STEEL)
    d.ellipse((4, 4, 11, 11), fill=WATER)
    put(top, [(6, 6), (7, 6)], WATER_L)
    save(top, "cistern_top")


def sign():
    """Wildlife rescue sign: a wooden board with a green paw."""
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 15, 15), fill=WOOD)
    for y in (4, 9, 14):
        d.line((0, y, 15, y), fill=WOOD_D)
    d.rectangle((2, 2, 13, 13), fill=hexc("#f1ead6"))
    d.ellipse((5, 7, 10, 12), fill=GREEN)
    for (x, y) in ((4, 5), (6, 3), (9, 3), (11, 5)):
        d.ellipse((x - 1, y - 1, x + 1, y + 1), fill=GREEN)
    save(im, "sign")


# ---------------------------------------------------------------- particles

def particles():
    im = img(8, 8)
    d = ImageDraw.Draw(im)
    d.ellipse((0, 1, 7, 7), fill=(255, 255, 255, 150))
    d.ellipse((1, 0, 5, 4), fill=(255, 255, 255, 190))
    save(im, "smoke")

    im = img(3, 3)
    put(im, [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)], FLAME)
    im.putpixel((1, 1), FLAME_L)
    save(im, "ember")

    im = img(4, 6)
    d = ImageDraw.Draw(im)
    d.polygon([(1, 0), (3, 3), (0, 3)], fill=WATER)
    d.ellipse((0, 2, 3, 5), fill=WATER)
    im.putpixel((1, 3), WATER_L)
    save(im, "drop")

    im = img(3, 3)
    put(im, [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)], hexc("#6b4a2b"))
    save(im, "crumb")

    im = img(7, 7)
    put(im, [(3, 0), (3, 1), (3, 5), (3, 6), (0, 3), (1, 3), (5, 3), (6, 3)], (255, 255, 255, 180))
    put(im, [(2, 2), (4, 2), (2, 4), (4, 4)], (255, 255, 255, 120))
    put(im, [(3, 2), (2, 3), (3, 3), (4, 3), (3, 4)], (255, 255, 255, 255))
    save(im, "sparkle")

    im = img(5, 9)
    d = ImageDraw.Draw(im)
    d.rectangle((1, 0, 3, 5), fill=FLAME_L)
    d.rectangle((1, 7, 3, 8), fill=FLAME_L)
    save(outline(im), "alarm")

    im = img(7, 6)
    d = ImageDraw.Draw(im)
    d.ellipse((0, 1, 3, 4), fill=hexc("#ff7aa8"))
    d.ellipse((3, 1, 6, 4), fill=hexc("#ff7aa8"))
    d.polygon([(0, 3), (6, 3), (3, 6)], fill=hexc("#ff7aa8"))
    save(im, "heart")


def main():
    save(flapper(), "flapper")
    save(pump(), "pump")
    save(rake(), "rake")
    save(carrier(), "carrier")
    save(game_icon(), "icon")
    save(hud_fire(), "hud_fire")
    save(hud_paw(), "hud_paw")
    save(hud_burned(), "hud_burned")
    save(hud_water(), "hud_water")
    save(hud_water(True), "hud_water_empty")
    scorched()
    charred_log()
    cistern()
    sign()
    particles()
    print("textures written to", TEXTURES)


if __name__ == "__main__":
    main()
