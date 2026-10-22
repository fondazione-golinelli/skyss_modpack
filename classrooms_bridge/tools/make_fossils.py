#!/usr/bin/env python3
"""Draws the 16x16 textures of the "Find the fossils" special mission.

Writes into ../textures:
  classrooms_bridge_fossil_<species>.png   found fossils (items)
  classrooms_bridge_fossil_traces.png      overlay: rock with a fossil inside
  classrooms_bridge_bone_traces.png        overlay: rock with a buried bone
  classrooms_bridge_dig_ground.png         background of uncovered bones
  classrooms_bridge_bone_<part>.png        overlay: uncovered bone, head to +X
  classrooms_bridge_fossil_hammer.png, _brush.png, _notebook.png,
  _detector.png                            tools
  classrooms_bridge_miner_helmet.png, _layer.png  miner's helmet (item, worn)

Run: python3 tools/make_fossils.py
"""
import math
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "textures")


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


def save(img, name):
    img.save(os.path.join(OUT, "classrooms_bridge_" + name + ".png"))


BONE = {
    "w": hexcolor("#eee6cf"),
    "b": hexcolor("#cdbf9a"),
    "d": hexcolor("#8f805e"),
    "k": hexcolor("#3d3426"),
}


def ammonite(outline, shell, light, dark, alpha=255):
    """A spiral shell with ribs, drawn from polar coordinates."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    cx, cy = 7.5, 7.5
    for y in range(16):
        for x in range(16):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            if r > 7.2:
                continue
            a = math.atan2(dy, dx) % (2 * math.pi)
            # Logarithmic spiral: whorl boundaries where r = c * e^(k * (a + 2 pi n)).
            t = math.log(max(r, 0.6) / 0.9) / 0.33 - a
            whorl = (t / (2 * math.pi)) % 1.0
            if r > 6.4 or whorl < 0.14:
                col = outline
            elif int(a / (math.pi / 8) + r) % 2 == 0:
                col = shell
            else:
                col = light
            if r < 1.2:
                col = dark
            img.putpixel((x, y), col[:3] + (alpha,))
    return img


def draw_species():
    stone = {
        "s": hexcolor("#8d8a84"), "t": hexcolor("#a8a49c"), "u": hexcolor("#6e6b66"),
    }
    # Ammonite: a brown spiral shell.
    save(ammonite(hexcolor("#5a4632"), hexcolor("#b98d55"), hexcolor("#e3c48b"), hexcolor("#6b4f30")), "fossil_ammonite")

    trilobite = from_ascii([
        "................",
        "......oooo......",
        "....oollllloo...",
        "...olllllllllo..",
        "...oddooooddo...",
        "...olmmlllmmlo..",
        "...odllmlmlldo..",
        "...olmmlllmmlo..",
        "...odllmlmlldo..",
        "....olmmlmmlo...",
        "....odlmmmldo...",
        ".....olmlmlo....",
        ".....odlmldo....",
        "......olmlo.....",
        ".......ooo......",
        "................",
    ], {"o": hexcolor("#3f3a33"), "l": hexcolor("#9c8f7c"), "m": hexcolor("#c7b9a2"),
        "d": hexcolor("#6d6355")})
    save(trilobite, "fossil_trilobite")

    tooth = from_ascii([
        "................",
        "................",
        "...rrrrrrrrrr...",
        "..rqqqqqqqqqqr..",
        "..rqqrrrrrrqqr..",
        "...ottttttto....",
        "...ottgttttto...",
        "...otgttttto....",
        "....otgtttto....",
        "....ottttto.....",
        ".....otgtto.....",
        ".....ottto......",
        "......otto......",
        "......oto.......",
        ".......o........",
        "................",
    ], {"r": hexcolor("#6b5a44"), "q": hexcolor("#8f7a5c"), "o": hexcolor("#1f2226"),
        "t": hexcolor("#4b5058"), "g": hexcolor("#8c939c")})
    save(tooth, "fossil_shark_tooth")

    fern = from_ascii([
        "................",
        ".ssssssssssssss.",
        ".stssssssggsuss.",
        ".ssssggsgsssss..",
        ".stsssggsgsgsss.",
        ".sssgggssgggsss.",
        ".ssssgggsgggsts.",
        ".susgggsgggssss.",
        ".sssssggsgggsss.",
        ".stsgggsgggsuss.",
        ".sssssgsgggssss.",
        ".ssusggsgssssts.",
        ".sssssssgsssss..",
        ".stsssssgssusss.",
        "..ssssssssssss..",
        "................",
    ], dict(stone, g=hexcolor("#4f5a3c")))
    save(fern, "fossil_fern")

    fish = from_ascii([
        "................",
        ".ssssssssssssss.",
        ".stssssssssssss.",
        ".ssssssssssusss.",
        ".sssbsbsbsssbbs.",
        ".ssbsbsbsbsbbss.",
        ".sbbbbbbbbbbkbs.",
        ".bwwwwwwwwwwbbs.",
        ".sbbbbbbbbbbbbs.",
        ".ssbsbsbsbsbbss.",
        ".sssbsbsbsssbbs.",
        ".ssussssssssss..",
        ".sssssssssstsss.",
        ".stsssssusssss..",
        "..ssssssssssss..",
        "................",
    ], dict(stone, **BONE))
    save(fish, "fossil_fish")


def draw_overlays():
    # Rock with a fossil inside: a faint spiral that students learn to spot.
    traces = ammonite(hexcolor("#3b2f22"), hexcolor("#c8a76e"), hexcolor("#e8d3a4"), hexcolor("#5c4630"), alpha=215)
    small = traces.resize((10, 10), Image.NEAREST)
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    img.paste(small, (3, 3), small)
    save(img, "fossil_traces")

    bone = from_ascii([
        "................",
        "................",
        "................",
        "..bb............",
        ".bwwb...........",
        ".bwwwb..........",
        "..bwwwb.........",
        "...bwwwb........",
        "....bwwwb.......",
        ".....bwwwb......",
        "......bwwwbb....",
        ".......bwwwwb...",
        "........bwwwb...",
        ".........bbb....",
        "................",
        "................",
    ], {"w": hexcolor("#eee6cf", 190), "b": hexcolor("#8f805e", 200)})
    save(bone, "bone_traces")

    rng = random.Random(7)
    ground = Image.new("RGBA", (16, 16))
    tones = [hexcolor("#c9b48a"), hexcolor("#bba57a"), hexcolor("#d6c39b"), hexcolor("#a8926a")]
    for y in range(16):
        for x in range(16):
            ground.putpixel((x, y), tones[rng.choice([0, 0, 0, 1, 1, 2, 3])])
    save(ground, "dig_ground")


def draw_bones():
    parts = {
        "skull": [
            "................",
            "................",
            "...bbbbb........",
            "..bwwwwwbb......",
            ".bwwkkwwwwbbb...",
            ".bwkkkwwwwwwwbb.",
            "bwwwwwwwwwwwwwwb",
            "bwwwwwwwwwwwwkwb",
            "bwwwwwwwwwwwwkwb",
            "bwwwwwwwwwwwwwwb",
            ".bwkkkwwwwwwwbb.",
            ".bwwkkwwwwbbb...",
            "..bwwwwwbb......",
            "...bbbbb........",
            "................",
            "................",
        ],
        "spine": [
            "................",
            "................",
            "................",
            "................",
            "..b...b...b...b.",
            ".bwb.bwb.bwb.bwb",
            "bbwbbbwbbbwbbbwb",
            "wwwwdwwwwdwwwwdw",
            "wwwwdwwwwdwwwwdw",
            "bbwbbbwbbbwbbbwb",
            ".bwb.bwb.bwb.bwb",
            "..b...b...b...b.",
            "................",
            "................",
            "................",
            "................",
        ],
        "rib": [
            "..bb....bb....bb",
            ".bwb...bwb...bwb",
            ".bwb...bwb...bwb",
            "bwb...bwb...bwb.",
            "bwb...bwb...bwb.",
            "bwb...bwb...bwb.",
            "bwbbbbbwbbbbbwbb",
            "wwwwdwwwwdwwwwdw",
            "wwwwdwwwwdwwwwdw",
            "bwbbbbbwbbbbbwbb",
            "bwb...bwb...bwb.",
            "bwb...bwb...bwb.",
            "bwb...bwb...bwb.",
            ".bwb...bwb...bwb",
            ".bwb...bwb...bwb",
            "..bb....bb....bb",
        ],
        "limb": [
            "......bbbb......",
            ".....bwwwwb.....",
            ".....bwwwwb.....",
            "......bwwb......",
            "......bwwb......",
            "......bwwb......",
            "......bwdb......",
            "......bwwb......",
            "......bwwb......",
            "......bwdb......",
            "......bwwb......",
            "......bwwb......",
            ".....bwwwwb.....",
            "....bwwbbwwb....",
            "....bbb..bbb....",
            "................",
        ],
        "tail": [
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "...........b...b",
            ".b..b..b..bwbbbw",
            "bwbbwbbwbbwwwdww",
            ".b..b..b..bwbbbw",
            "...........b...b",
            "................",
            "................",
            "................",
            "................",
            "................",
        ],
    }
    for name, rows in parts.items():
        save(from_ascii(rows, BONE), "bone_" + name)


def draw_tools():
    hammer = from_ascii([
        "................",
        "......mmmmm.....",
        ".....mllllmm....",
        "....mlmmmmmlm...",
        "...mlm..hmmmlm..",
        "...mm..hh.mmlm..",
        "......hh...mm...",
        ".....hh.........",
        "....hh..........",
        "...hh...........",
        "..hh............",
        ".hh.............",
        "hh..............",
        "h...............",
        "................",
        "................",
    ], {"m": hexcolor("#4d5560"), "l": hexcolor("#b9c2cc"), "h": hexcolor("#8a5a2e")})
    save(hammer, "fossil_hammer")

    brush = from_ascii([
        "................",
        "...........yyy..",
        "..........yyyyy.",
        ".........yyyyyy.",
        "........yyyyyy..",
        ".......ccyyyy...",
        "......cccyy.....",
        ".....hcc........",
        "....hh..........",
        "...hh...........",
        "..hh............",
        ".hh.............",
        "hh..............",
        "h...............",
        "................",
        "................",
    ], {"y": hexcolor("#e3c770"), "c": hexcolor("#b87333"), "h": hexcolor("#7a4a24")})
    save(brush, "fossil_brush")

    notebook = from_ascii([
        "................",
        "..rrrrrrrrrrr...",
        "..rbbbbbbbbbrp..",
        "..rbbbbbbbbbrp..",
        "..rbbwwwwwbbrp..",
        "..rbbwddwwbbrp..",
        "..rbbwwwwwbbrp..",
        "..rbbbbbbbbbrp..",
        "..sssssssssssp..",
        "..rbbbbbbbbbrp..",
        "..rbbbbbbbbbrp..",
        "..rbbbbbbbbbrp..",
        "..rbbbbbbbbbrp..",
        "..rrrrrrrrrrrp..",
        "...pppppppppp...",
        "................",
    ], {"r": hexcolor("#4a2f1c"), "b": hexcolor("#7b4f2c"), "w": hexcolor("#e9dfc4"),
        "d": hexcolor("#8f805e"), "s": hexcolor("#2e1d11"), "p": hexcolor("#efe8d6")})
    save(notebook, "fossil_notebook")

    detector = from_ascii([
        "................",
        "..........aa....",
        ".........a..a...",
        "..........a.....",
        "....kkkkkkkk....",
        "...kyyyyyyyyk...",
        "...kygggggyyk...",
        "...kyggrgggyk...",
        "...kygggggyyk...",
        "...kyyyyyyyyk...",
        "...kyyrryyyyk...",
        "...kyyrryooyk...",
        "...kyyyyyyyyk...",
        "....kkkkkkkk....",
        "................",
        "................",
    ], {"k": hexcolor("#2b2f36"), "y": hexcolor("#e0a92e"), "g": hexcolor("#3e8f5a"),
        "r": hexcolor("#d84a3a"), "o": hexcolor("#5aa0e0"), "a": hexcolor("#8c939c")})
    save(detector, "fossil_detector")

    helmet = from_ascii([
        "................",
        "................",
        "................",
        "......kkkk......",
        "....kyyyyyyk....",
        "...kyhyyllyyk...",
        "..kyhyylwwlyyk..",
        "..kyyyylwwlyyk..",
        "..kyyyyyllyyyk..",
        "..kyyyyyyyyyyk..",
        ".kddddddddddddk.",
        ".kkkkkkkkkkkkkk.",
        "................",
        "................",
        "................",
        "................",
    ], {"k": hexcolor("#3a3020"), "y": hexcolor("#f2c230"), "h": hexcolor("#fff0a0"),
        "d": hexcolor("#b38a1a"), "l": hexcolor("#6b6f76"), "w": hexcolor("#fffbe0")})
    save(helmet, "miner_helmet")


def draw_helmet_layer():
    """The helmet on the player model: the hat layer of the 64x32 armor
    texture (top 40-47 x 0-7; sides, front and back 32-63 x 8-15)."""
    yellow, light, dark = hexcolor("#f2c230"), hexcolor("#ffe27a"), hexcolor("#b38a1a")
    lamp_ring, lamp = hexcolor("#6b6f76"), hexcolor("#fffbe0")
    img = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    for y in range(8):
        for x in range(40, 48):
            img.putpixel((x, y), light if (x + y) % 5 == 0 else yellow)
    for y in range(8, 12):
        for x in range(32, 64):
            img.putpixel((x, y), dark if y == 11 else yellow)
    # The lamp on the forehead (front face 40-47).
    for y in range(8, 11):
        for x in range(42, 46):
            edge = y in (8, 10) or x in (42, 45)
            img.putpixel((x, y), lamp_ring if edge else lamp)
    save(img, "miner_helmet_layer")


if __name__ == "__main__":
    draw_species()
    draw_overlays()
    draw_bones()
    draw_tools()
    draw_helmet_layer()
    print("fossil textures written to", os.path.normpath(OUT))
