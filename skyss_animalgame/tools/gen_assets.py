#!/usr/bin/env python3
"""Generate the Animal Sounds pixel-art textures.

Run from anywhere:  python3 tools/gen_assets.py
Outputs go to ../textures (relative to this script). Colour-neutral masks
(podium band and ring) are white so the mod can tint them per station with
[multiply.
"""
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEXTURES = os.path.join(ROOT, "textures")
PREFIX = "skyss_animalgame_"


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (c[3],)


def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def save(im, name):
    im.save(os.path.join(TEXTURES, PREFIX + name + ".png"), optimize=True)


# ---------------------------------------------------------------- podium

STONE = hexc("#e6dfcf")


def stone(im, rng, box):
    x0, y0, x1, y1 = box
    for x in range(x0, x1):
        for y in range(y0, y1):
            im.putpixel((x, y), shade(STONE, rng.choice((0.94, 0.97, 1.0, 1.0, 1.03))))


def podium():
    rng = random.Random(7)

    # Side: polished stone, dark plinth at the bottom, a light top lip.
    im = img(16, 16)
    stone(im, rng, (0, 0, 16, 16))
    for x in range(16):
        im.putpixel((x, 0), shade(STONE, 1.08))
        im.putpixel((x, 1), shade(STONE, 0.86))
        for y in (13, 14, 15):
            im.putpixel((x, y), shade(hexc("#6f6457"), 1.1 if y == 13 else 1.0))
    for y in range(2, 13):
        im.putpixel((0, y), shade(im.getpixel((0, y)), 0.9))
        im.putpixel((15, y), shade(im.getpixel((15, y)), 0.9))
    save(im, "podium_side")

    # Coloured band across the side, tinted per station.
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 3, 15, 6), fill=(255, 255, 255, 255))
    for x in range(16):
        im.putpixel((x, 3), (255, 255, 255, 255))
        im.putpixel((x, 6), (205, 205, 205, 255))
    save(im, "podium_band")

    # Top: stone slab with a bevelled border.
    im = img(16, 16)
    stone(im, rng, (0, 0, 16, 16))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 15, 15), outline=shade(STONE, 0.84))
    save(im, "podium_top")

    # Ring around the top, tinted per station.
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle((1, 1, 14, 14), outline=(255, 255, 255, 255), width=2)
    save(im, "podium_ring")


# ---------------------------------------------------------------- particles

def particles():
    im = img(7, 7)
    d = ImageDraw.Draw(im)
    d.line((3, 0, 3, 6), fill=(255, 255, 255, 230))
    d.line((0, 3, 6, 3), fill=(255, 255, 255, 230))
    d.point((3, 3), fill=(255, 255, 255, 255))
    for p in ((2, 2), (4, 4), (2, 4), (4, 2)):
        d.point(p, fill=(255, 255, 255, 120))
    save(im, "sparkle")

    # Eighth note, white so it can be tinted.
    im = img(8, 10)
    d = ImageDraw.Draw(im)
    d.ellipse((0, 6, 4, 9), fill=(255, 255, 255, 255))
    d.line((4, 0, 4, 7), fill=(255, 255, 255, 255))
    d.line((4, 0, 7, 3), fill=(255, 255, 255, 255))
    d.point((7, 4), fill=(255, 255, 255, 255))
    save(im, "note")

    im = img(8, 8)
    px = im.load()
    for x in range(8):
        for y in range(8):
            r = ((x - 3.5) ** 2 + (y - 3.5) ** 2) ** 0.5
            if r < 4:
                px[x, y] = (255, 255, 255, int(200 * (1 - r / 4)))
    save(im, "puff")


# ---------------------------------------------------------------- hud

HEART = [
    ".##.##.",
    "#######",
    "#######",
    ".#####.",
    "..###..",
    "...#...",
]


def hearts():
    for name, fill, edge in (("heart", "#ff4d5e", "#8c1a26"), ("heart_empty", "#3a3f44", "#1c1f22")):
        im = img(9, 8)
        rows = [row.replace(".", " ") for row in HEART]
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "#":
                    im.putpixel((x + 1, y + 1), hexc(fill))
        # Outline from the filled shape.
        px = im.load()
        edges = []
        for y in range(8):
            for x in range(9):
                if px[x, y][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < 9 and 0 <= ny < 8 and px[nx, ny][3] == 255 and px[nx, ny][:3] == hexc(fill)[:3]:
                        edges.append((x, y))
                        break
        for p in edges:
            px[p] = hexc(edge)
        if name == "heart":
            px[2, 2] = hexc("#ffc2c8")
        save(im, name)


def icon():
    # Speaker with sound waves: the minigame icon.
    im = img(32, 32)
    d = ImageDraw.Draw(im)
    body = hexc("#ffb347")
    dark = hexc("#7a4a12")
    d.polygon([(2, 11), (8, 11), (15, 4), (15, 27), (8, 20), (2, 20)], fill=body, outline=dark)
    d.rectangle((3, 12, 7, 19), fill=shade(body, 1.15))
    d.line((14, 6, 14, 25), fill=shade(body, 0.8))
    for r, a in ((5, 255), (10, 235), (15, 200)):
        d.arc((15 - r, 16 - r, 15 + r, 16 + r), -45, 45, fill=(255, 255, 255, a), width=2)
    save(im, "icon")

    # Fallback bell sprite when mcl_bells is missing.
    im = img(16, 16)
    d = ImageDraw.Draw(im)
    gold = hexc("#f2c230")
    d.rectangle((7, 1, 8, 2), fill=shade(gold, 0.6))
    d.polygon([(5, 3), (10, 3), (12, 11), (3, 11)], fill=gold, outline=shade(gold, 0.55))
    d.rectangle((2, 11, 13, 12), fill=shade(gold, 0.8), outline=shade(gold, 0.55))
    d.line((6, 5, 5, 10), fill=shade(gold, 1.25))
    d.rectangle((7, 13, 8, 14), fill=shade(gold, 0.5))
    save(im, "bell")


def main():
    os.makedirs(TEXTURES, exist_ok=True)
    podium()
    particles()
    hearts()
    icon()


if __name__ == "__main__":
    main()
