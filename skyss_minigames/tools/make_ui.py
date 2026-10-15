#!/usr/bin/env python3
"""Draws the pixel-art backgrounds and buttons of the skyss_minigames menus.

Same look as the serverguide books: a wooden board hanging from a leafy beam,
parchment, wooden plaques for titles, light-green panels and grass at the
bottom. Layouts are in formspec units (15 px each) and are also written to
src/ui_layout.lua, so the Lua code places text exactly on the drawn panels.

Run from anywhere: python3 tools/make_ui.py
"""
import math
import os
import random

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, "..", "textures")
LAYOUT_LUA = os.path.join(HERE, "..", "src", "ui_layout.lua")
U = 15  # pixels per formspec unit

# serverguide palette
PARCH, SPECK = (243, 234, 208), (216, 201, 160)
PANEL, PANEL_ROW, PANEL_EDGE = (210, 228, 182), (196, 218, 165), (165, 122, 69)
WOOD, WOOD_HI, WOOD_LO, WOOD_DARK, WOOD_GRAIN = (189, 148, 87), (210, 173, 112), (138, 98, 56), (110, 74, 42), (165, 122, 69)
LEAF_DARK, LEAF, LEAF_HI, LEAF_DEEP = (63, 122, 51), (87, 153, 61), (125, 184, 74), (31, 63, 36)
INK = (48, 44, 46)
FLOWERS = [(232, 80, 70), (255, 214, 92), (240, 240, 240), (224, 140, 200)]


def px(u):
    return int(round(u * U))


def rect(d, x, y, w, h, fill):
    d.rectangle([px(x), px(y), px(x + w) - 1, px(y + h) - 1], fill=fill)


def parchment(img, d, x, y, w, h, rng):
    rect(d, x, y, w, h, PARCH)
    for _ in range(int(w * h * 6)):
        d.point((rng.randint(px(x), px(x + w) - 1), rng.randint(px(y), px(y + h) - 1)), fill=SPECK)


def wood_frame(d, x, y, w, h, rng, t=0.3):
    x0, y0, x1, y1 = px(x), px(y), px(x + w) - 1, px(y + h) - 1
    tt = px(t)
    d.rectangle([x0, y0, x1, y1], fill=WOOD_LO)
    d.rectangle([x0, y0, x1, y1], outline=WOOD_DARK)
    d.rectangle([x0 + tt - 1, y0 + tt - 1, x1 - tt + 1, y1 - tt + 1], outline=WOOD_DARK)
    for _ in range(int((w + h) * 5)):
        if rng.random() < 0.5:
            gx, gy = rng.randint(x0 + 1, x1 - 6), rng.choice([rng.randint(y0 + 1, y0 + tt - 2), rng.randint(y1 - tt + 2, y1 - 1)])
            d.line([gx, gy, gx + rng.randint(2, 5), gy], fill=WOOD_DARK)
        else:
            gy, gx = rng.randint(y0 + 1, y1 - 6), rng.choice([rng.randint(x0 + 1, x0 + tt - 2), rng.randint(x1 - tt + 2, x1 - 1)])
            d.line([gx, gy, gx, gy + rng.randint(2, 5)], fill=WOOD_DARK)
    return x + t, y + t, w - 2 * t, h - 2 * t


def plaque(d, x, y, w, h, rng):
    x0, y0, x1, y1 = px(x), px(y), px(x + w) - 1, px(y + h) - 1
    d.rectangle([x0, y0, x1, y1], fill=WOOD, outline=WOOD_DARK)
    d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=WOOD_HI)
    d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=WOOD_LO)
    for _ in range(int(w * 3)):
        gx, gy = rng.randint(x0 + 4, x1 - 10), rng.randint(y0 + 3, y1 - 3)
        d.line([gx, gy, gx + rng.randint(3, 8), gy], fill=WOOD_GRAIN)
    for nx in (x0 + 3, x1 - 3):
        d.point((nx, (y0 + y1) // 2), fill=WOOD_DARK)


def panel(d, x, y, w, h, rows=None):
    x0, y0, x1, y1 = px(x), px(y), px(x + w) - 1, px(y + h) - 1
    d.rectangle([x0, y0, x1, y1], fill=PANEL, outline=PANEL_EDGE)
    d.rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], outline=WOOD_HI)
    for c in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        d.point(c, fill=PARCH)
    if rows:
        top, step, count = rows
        for i in range(count):
            if i % 2 == 0:
                d.rectangle([x0 + 3, px(top + i * step), x1 - 3, px(top + (i + 1) * step) - 1], fill=PANEL_ROW)


def slot(d, x, y, w, h):
    x0, y0, x1, y1 = px(x), px(y), px(x + w) - 1, px(y + h) - 1
    d.rectangle([x0, y0, x1, y1], fill=PANEL, outline=PANEL_EDGE)
    d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=(228, 240, 206))


def bush(d, cx, cy, r, rng):
    for _ in range(5):
        ox, oy = rng.randint(-r, r), rng.randint(-r // 2, r // 2)
        rr = rng.randint(max(3, r // 2), r)
        d.ellipse([cx + ox - rr - 1, cy + oy - rr - 1, cx + ox + rr + 1, cy + oy + rr + 1], fill=LEAF_DARK)
    for _ in range(5):
        ox, oy = rng.randint(-r, r), rng.randint(-r // 2, r // 2)
        rr = rng.randint(max(2, r // 2 - 1), r - 1)
        d.ellipse([cx + ox - rr, cy + oy - rr, cx + ox + rr, cy + oy + rr], fill=LEAF)
        d.ellipse([cx + ox - rr // 2, cy + oy - rr + 1, cx + ox + rr // 3, cy + oy - rr // 3], fill=LEAF_HI)


def foliage_beam(d, w_units, rng, beam_y=0.45):
    W = px(w_units)
    by = px(beam_y)
    d.rectangle([0, by - 2, W - 1, by + 2], fill=WOOD_DARK)
    d.line([0, by - 1, W - 1, by - 1], fill=WOOD_LO)
    x = 4
    while x < W:
        bush(d, x, by - 3, rng.randint(6, 9), rng)
        x += rng.randint(10, 16)
    for _ in range(int(w_units * 1.5)):
        d.point((rng.randint(3, W - 4), rng.randint(1, by - 2)), fill=rng.choice(FLOWERS))


def ropes(d, x_units, top, bottom):
    for xu in x_units:
        x = px(xu)
        for y in range(px(top), px(bottom)):
            d.point((x, y), fill=WOOD_GRAIN if y % 2 else WOOD_LO)


def grass(d, w_units, y_units, h_units, rng):
    W, y0, y1 = px(w_units), px(y_units), px(y_units + h_units) - 1
    d.rectangle([0, y0 + 3, W - 1, y1], fill=LEAF_DARK)
    d.rectangle([0, y0 + 5, W - 1, y1], fill=LEAF)
    for x in range(0, W, 2):
        hgt = rng.randint(2, 6)
        d.line([x, y0 + 5, x, y0 + 5 - hgt], fill=rng.choice([LEAF, LEAF_HI, LEAF_DARK]))
    for _ in range(int(w_units * 0.8)):
        fx = rng.randint(2, W - 3)
        d.point((fx, y0 + rng.randint(0, 3)), fill=rng.choice(FLOWERS))
    for mx in rng.sample(range(8, W - 8), max(1, int(w_units / 6))):
        d.rectangle([mx - 1, y0 + 2, mx + 1, y0 + 6], fill=(240, 232, 214))
        d.rectangle([mx - 3, y0, mx + 3, y0 + 2], fill=(200, 60, 50))
        d.point((mx - 1, y0), fill=(250, 250, 250))
        d.point((mx + 2, y0 + 1), fill=(250, 250, 250))


def vine(d, x, y, w, rng):
    x0, x1, y0 = px(x), px(x + w), px(y)
    for xx in range(x0, x1):
        yy = y0 + int(round(math.sin(xx / 5.0)))
        d.point((xx, yy), fill=LEAF_DARK)
        if rng.random() < 0.18:
            d.point((xx, yy - 1), fill=LEAF)
            d.point((xx + 1, yy - 1), fill=LEAF_HI)


def icon_frame(d, x, y, s):
    x0, y0, x1, y1 = px(x), px(y), px(x + s) - 1, px(y + s) - 1
    d.rectangle([x0, y0, x1, y1], fill=WOOD_DARK)
    d.rectangle([x0 + 2, y0 + 2, x1 - 2, y1 - 2], fill=WOOD)
    d.rectangle([x0 + 3, y0 + 3, x1 - 3, y1 - 3], fill=PANEL, outline=WOOD_LO)


# ── Layouts (formspec units) ──────────────────────────────────────────────

FRAME = (0.35, 0.8)
TITLE = {"icon": (0.85, 1.08, 1.3), "plaque": (2.35, 1.12, 8.6, 0.95), "close": (12.75, 1.2, 0.7, 0.7)}

LAYOUTS = {
    "game": {
        "size": (14, 10.6),
        "title": TITLE,
        "panels": {
            "how": (0.85, 2.95, 6.4, 2.1),
            "now": (0.85, 6.55, 6.4, 1.9),
            "board": (7.55, 2.95, 5.6, 5.5),
        },
        "tabs": {"how": (1.05, 2.68, 3.4, 0.52), "now": (1.05, 6.28, 3.4, 0.52), "board": (7.75, 2.68, 3.0, 0.52)},
        "slots": {"chip1": (0.85, 5.3, 2.05, 0.8), "chip2": (3.02, 5.3, 2.05, 0.8), "chip3": (5.2, 5.3, 2.05, 0.8)},
        "rows": {"board": (3.4, 0.5, 10)},
        "vine": (0.9, 8.68, 12.2),
        "buttons_y": 8.92,
    },
    "staff": {
        "size": (14, 10.6),
        "title": TITLE,
        "panels": {
            "players": (0.85, 2.95, 7.6, 5.5),
            "settings": (8.75, 2.95, 4.4, 2.45),
            "matches": (8.75, 6.0, 4.4, 2.45),
        },
        "tabs": {"players": (1.05, 2.68, 4.4, 0.52), "settings": (8.95, 2.68, 3.0, 0.52), "matches": (8.95, 5.73, 3.0, 0.52)},
        "slots": {"minutes": (8.95, 3.95, 1.5, 0.65)},
        "rows": {},
        "vine": (0.9, 8.68, 12.2),
        "buttons_y": 8.92,
    },
    "editor": {
        "size": (14, 10.6),
        "title": TITLE,
        "panels": {"main": (0.85, 3.15, 12.3, 5.35)},
        "tabs": {},
        "slots": {},
        "rows": {},
        "vine": (0.9, 8.68, 12.2),
        "buttons_y": 8.92,
    },
    "leave": {
        "size": (9, 5.6),
        "title": {"icon": (0.85, 1.08, 1.3), "plaque": (2.35, 1.12, 5.0, 0.95), "close": None},
        "panels": {},
        "tabs": {},
        "slots": {},
        "rows": {},
        "vine": None,
        "buttons_y": 3.85,
    },
    "board": {
        "size": (8.4, 10.6),
        "title": {"icon": (0.85, 1.08, 1.3), "plaque": (2.35, 1.12, 4.3, 0.95), "close": (7.15, 1.2, 0.7, 0.7)},
        "panels": {"board": (0.85, 2.95, 6.7, 5.5)},
        "tabs": {"board": (1.05, 2.68, 3.0, 0.52)},
        "slots": {},
        "rows": {"board": (3.4, 0.5, 10)},
        "vine": (0.9, 8.68, 6.6),
        "buttons_y": 8.92,
    },
}


def draw_layout(name, lay):
    rng = random.Random(name)
    W, H = lay["size"]
    img = Image.new("RGBA", (px(W), px(H)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    grass_h = 0.6
    fx, fy = FRAME
    frame = (fx, fy, W - 2 * fx, H - fy - grass_h + 0.15)
    ropes(d, (2.0, W - 2.0), 0.45, fy + 0.1)
    inner = wood_frame(d, *frame, rng)
    parchment(img, d, *inner, rng)
    foliage_beam(d, W, rng)
    t = lay["title"]
    icon_frame(d, *t["icon"])
    plaque(d, *t["plaque"], rng)
    for key, p in lay["panels"].items():
        panel(d, *p, rows=lay["rows"].get(key))
    for p in lay["tabs"].values():
        plaque(d, *p, rng)
    for p in lay["slots"].values():
        slot(d, *p)
    if lay["vine"]:
        vine(d, *lay["vine"], rng)
    grass(d, W, H - grass_h, grass_h, rng)
    img.save(os.path.join(TEX, f"skyss_minigames_ui_{name}.png"))


# ── Buttons, medals, close ────────────────────────────────────────────────

BUTTONS = {
    "green": ((87, 153, 61), (125, 184, 74), (63, 122, 51), (31, 63, 36)),
    "wood": ((189, 148, 87), (210, 173, 112), (138, 98, 56), (110, 74, 42)),
    "red": ((192, 80, 63), (217, 112, 92), (143, 53, 41), (90, 31, 25)),
    "blue": ((63, 128, 190), (100, 160, 215), (45, 95, 150), (25, 52, 90)),
}


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def button(name, colours, state):
    base, hi, lo, border = colours
    if state == "hover":
        base, hi = shade(base, 1.12), shade(hi, 1.1)
    elif state == "pressed":
        base, hi, lo = shade(base, 0.85), shade(base, 0.85), shade(lo, 0.9)
    img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 0, 30, 15], fill=border)
    d.rectangle([0, 1, 31, 14], fill=border)
    d.rectangle([1, 1, 30, 14], fill=base)
    if state != "pressed":
        d.line([2, 1, 29, 1], fill=hi)
        d.line([1, 2, 1, 12], fill=hi)
        d.rectangle([1, 12, 30, 14], fill=lo)
    else:
        d.rectangle([1, 1, 30, 2], fill=lo)
    suffix = "" if state == "normal" else "_" + state
    img.save(os.path.join(TEX, f"skyss_minigames_btn_{name}{suffix}.png"))


def medal(name, fill, rim):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(4, 0), (7, 0), (8, 5), (5, 5)], fill=(63, 128, 190))
    d.polygon([(9, 0), (12, 0), (11, 5), (8, 5)], fill=(192, 80, 63))
    d.ellipse([2, 4, 13, 15], fill=rim)
    d.ellipse([3, 5, 12, 14], fill=fill)
    d.ellipse([4, 6, 7, 9], fill=shade(fill, 1.2))
    img.save(os.path.join(TEX, f"skyss_minigames_medal_{name}.png"))


def icons():
    """Small dark icons for the info slots, readable on the light panels."""
    def new():
        return Image.new("RGBA", (16, 16), (0, 0, 0, 0))

    def person(d, cx, top, body, head):
        d.rectangle([cx - 1, top, cx + 1, top + 2], fill=head)
        d.rectangle([cx - 2, top + 4, cx + 2, top + 9], fill=body)

    img = new(); d = ImageDraw.Draw(img)
    person(d, 7, 2, LEAF_DARK, WOOD_DARK)
    d.rectangle([5, 6, 9, 12], fill=LEAF_DARK)
    img.save(os.path.join(TEX, "skyss_minigames_ui_solo.png"))
    img = new(); d = ImageDraw.Draw(img)
    for cx, body in ((3, LEAF), (8, LEAF_DARK), (13, LEAF)):
        person(d, cx, 3, body, WOOD_DARK)
    d.line([3, 9, 13, 9], fill=WOOD_DARK)
    img.save(os.path.join(TEX, "skyss_minigames_ui_coop.png"))
    img = new(); d = ImageDraw.Draw(img)
    person(d, 5, 3, WOOD_LO, WOOD_DARK)
    person(d, 10, 4, LEAF_DARK, WOOD_DARK)
    img.save(os.path.join(TEX, "skyss_minigames_ui_people.png"))
    img = new(); d = ImageDraw.Draw(img)
    d.ellipse([1, 1, 14, 14], fill=WOOD_DARK)
    d.ellipse([2, 2, 13, 13], fill=(250, 245, 228))
    d.rectangle([7, 4, 8, 8], fill=INK)
    d.rectangle([8, 7, 11, 8], fill=INK)
    img.save(os.path.join(TEX, "skyss_minigames_ui_clock.png"))
    img = Image.new("RGBA", (8, 8), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    d.ellipse([0, 0, 7, 7], fill=(255, 255, 255))
    img.save(os.path.join(TEX, "skyss_minigames_ui_dot.png"))


def tool_icons():
    """One icon per edit tool: a coloured disc with a white glyph."""
    W = (249, 243, 223)
    glyphs = {
        "select": ((63, 128, 190), [(5, 4), (5, 5), (5, 6), (5, 7), (5, 8), (5, 9), (5, 10), (6, 5), (6, 6), (6, 7), (6, 8), (6, 9),
                                    (7, 6), (7, 7), (7, 8), (8, 7), (8, 8), (9, 8), (7, 9), (8, 10), (9, 11)]),
        "corners": ((224, 180, 63), [(4, 4), (5, 4), (6, 4), (4, 5), (4, 6), (11, 11), (10, 11), (9, 11), (11, 10), (11, 9)]),
        "spawn": ((87, 153, 61), [(7, 3), (8, 3), (6, 4), (7, 4), (8, 4), (9, 4), (7, 5), (8, 5), (6, 7), (7, 7), (8, 7), (9, 7),
                                  (7, 8), (8, 8), (7, 9), (8, 9), (6, 10), (9, 10), (6, 11), (9, 11)]),
        "launcher": ((189, 148, 87), [(5, 4), (6, 4), (7, 4), (8, 4), (9, 4), (10, 4), (7, 5), (8, 5), (7, 6), (8, 6), (7, 7), (8, 7),
                                      (7, 8), (8, 8), (7, 9), (8, 9), (5, 10), (6, 10), (7, 10), (8, 10), (9, 10), (10, 10)]),
        "exit": ((100, 160, 215), [(4, 7), (5, 7), (6, 7), (7, 7), (8, 7), (9, 7), (10, 7), (8, 5), (9, 6), (8, 9), (9, 8),
                                   (11, 4), (11, 5), (11, 6), (11, 8), (11, 9), (11, 10)]),
        "done": ((192, 80, 63), [(4, 8), (5, 9), (6, 10), (7, 9), (8, 8), (9, 7), (10, 6), (11, 5), (5, 8), (6, 9), (7, 8),
                                 (8, 7), (9, 6), (10, 5)]),
    }
    for name, (colour, pts) in glyphs.items():
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse([0, 0, 15, 15], fill=shade(colour, 0.6))
        d.ellipse([1, 1, 14, 14], fill=colour)
        d.ellipse([3, 2, 7, 5], fill=shade(colour, 1.18))
        for p in pts:
            d.point(p, fill=W)
        img.save(os.path.join(TEX, f"skyss_minigames_tool_{name}.png"))


def field_slot():
    img = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 11, 11], fill=(250, 245, 228), outline=PANEL_EDGE)
    d.line([1, 1, 10, 1], fill=SPECK)
    img.save(os.path.join(TEX, "skyss_minigames_ui_slot.png"))


def close_button():
    for state, k in (("", 1.0), ("_hover", 1.12), ("_pressed", 0.85)):
        img = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, 11, 11], fill=(90, 31, 25))
        d.rectangle([1, 1, 10, 10], fill=shade((192, 80, 63), k))
        for i in range(3, 9):
            d.point((i, i), fill=(249, 243, 223))
            d.point((11 - i, i), fill=(249, 243, 223))
        img.save(os.path.join(TEX, f"skyss_minigames_close{state}.png"))


def lua_value(v):
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{k} = {lua_value(x)}" for k, x in v.items()) + " }"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_value(x) for x in v) + " }"
    if v is None:
        return "false"
    return repr(v)


def write_layout():
    with open(LAYOUT_LUA, "w") as f:
        f.write("-- Generated by tools/make_ui.py: positions of the panels drawn in the\n")
        f.write("-- skyss_minigames_ui_*.png backgrounds, in formspec units. Do not edit.\n")
        f.write("local P = ...\n\nP.LAYOUT = {\n")
        for name, lay in LAYOUTS.items():
            f.write(f"    {name} = {lua_value(lay)},\n")
        f.write("}\n")


if __name__ == "__main__":
    for name, lay in LAYOUTS.items():
        draw_layout(name, lay)
    for name, colours in BUTTONS.items():
        for state in ("normal", "hover", "pressed"):
            button(name, colours, state)
    medal("gold", (224, 180, 63), (138, 98, 56))
    medal("silver", (185, 193, 204), (110, 110, 120))
    medal("bronze", (194, 124, 74), (110, 74, 42))
    close_button()
    field_slot()
    icons()
    tool_icons()
    write_layout()
    print("done")
