#!/usr/bin/env python3
"""Draws the textures of skyss_paintings.

Writes into ../textures:
  skyss_paintings_frame.png          painting frame (empty canvas on an easel frame)
  skyss_paintings_frame_mission.png  the same with a mission star
  skyss_paintings_painting.png       painting item (fallback icon)
  skyss_paintings_blank.png          transparent, for invisible buttons and nodes
  skyss_paintings_hover.png          highlight of the pixel under the mouse
  skyss_paintings_bad.png            particle on a cell where a painting does not fit
  skyss_paintings_icon_<name>.png    UI icons: pencil, fill, undo, clear, grid, save,
                                     close, resize, new, draft, edit, remove, pivot,
                                     line, rect

Run: python3 tools/make_textures.py
"""
import os

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
    img.save(os.path.join(OUT, "skyss_paintings_" + name + ".png"))


WOOD = {
    "k": hexcolor("#3b2412"),
    "d": hexcolor("#6b4423"),
    "w": hexcolor("#a0703c"),
    "l": hexcolor("#c99a5b"),
    "c": hexcolor("#f4efe2"),
    "s": hexcolor("#dcd5c3"),
    "y": hexcolor("#fad64a"),
    "o": hexcolor("#f98e2c"),
    "r": hexcolor("#f04a4a"),
    "b": hexcolor("#36a6e0"),
    "g": hexcolor("#4cb848"),
    "G": hexcolor("#1e7d3a"),
    "B": hexcolor("#2156c2"),
    "W": hexcolor("#ffffff"),
}

FRAME = [
    "................",
    ".kkkkkkkkkkkkkk.",
    ".kllllllllllllk.",
    ".klwwwwwwwwwwdk.",
    ".klwccccccccwdk.",
    ".klwccccccccwdk.",
    ".klwccccccsswdk.",
    ".klwccccccsswdk.",
    ".klwcccccsscwdk.",
    ".klwccccssccwdk.",
    ".klwccccccccwdk.",
    ".klwccccccccwdk.",
    ".klwwwwwwwwwwdk.",
    ".kddddddddddddk.",
    ".kkkkkkkkkkkkkk.",
    "................",
]

PAINTING = [
    "................",
    ".kkkkkkkkkkkkkk.",
    ".kllllllllllllk.",
    ".klwwwwwwwwwwdk.",
    ".klwbbbbbyybwdk.",
    ".klwbbbbyyyywdk.",
    ".klwbbbbbyybwdk.",
    ".klwbWWbbbbbwdk.",
    ".klwWWWWbbbbwdk.",
    ".klwbbbbbbgbwdk.",
    ".klwgbbbbgggwdk.",
    ".klwGgggGGGGwdk.",
    ".klwwwwwwwwwwdk.",
    ".kddddddddddddk.",
    ".kkkkkkkkkkkkkk.",
    "................",
]


ICON = {
    "k": hexcolor("#1a1932"),
    "w": hexcolor("#ffffff"),
    "s": hexcolor("#c7cfdd"),
    "g": hexcolor("#92a1b9"),
    "y": hexcolor("#fad64a"),
    "o": hexcolor("#f98e2c"),
    "p": hexcolor("#f58fc0"),
    "r": hexcolor("#f04a4a"),
    "R": hexcolor("#b4202a"),
    "b": hexcolor("#36a6e0"),
    "B": hexcolor("#2156c2"),
    "e": hexcolor("#4cb848"),
    "E": hexcolor("#1e7d3a"),
    "l": hexcolor("#c99a5b"),
    "d": hexcolor("#6b4423"),
}

ICONS = {
    "pencil": [
        "................",
        "...........kk...",
        "..........kppk..",
        ".........kpppk..",
        "........kykppk..",
        ".......kyyykk...",
        "......kyyyok....",
        ".....kyyyok.....",
        "....kyyyok......",
        "...kyyyok.......",
        "...klyok........",
        "..kllkk.........",
        "..kkkk..........",
        "..kk............",
        "................",
        "................",
    ],
    "fill": [
        "................",
        "......kk........",
        ".....kssk.......",
        "....ksssskk.....",
        "...ksssssskk....",
        "..kssssssssk....",
        ".ksssssssssk....",
        ".kbbbbbbbbsk.b..",
        "..kbbbbbbbk..bb.",
        "...kbbbbbk...bb.",
        "....kbbbk...bbbb",
        ".....kbk....bbbb",
        "......k......bb.",
        "................",
        "................",
        "................",
    ],
    "undo": [
        "................",
        "................",
        ".....k..........",
        "....kbk.........",
        "...kbbkkkkkk....",
        "..kbbbbbbbbbkk..",
        "...kbbkkkkkbbbk.",
        "....kbk....kbbk.",
        ".....k......kbbk",
        "............kbbk",
        "............kbbk",
        "...........kbbk.",
        "......kkkkkbbk..",
        "......kbbbbbk...",
        "......kkkkkk....",
        "................",
    ],
    "clear": [
        "................",
        "......kkkk......",
        ".....kggggk.....",
        "..kkkkkkkkkkkk..",
        "..kssssssssssk..",
        "..kkkkkkkkkkkk..",
        "...kssgssgsssk..",
        "...ksgssgssgk...",
        "...ksgssgssgk...",
        "...ksgssgssgk...",
        "...ksgssgssgk...",
        "...ksgssgssgk...",
        "...ksgssgssgk...",
        "...kssssssssk...",
        "....kkkkkkkk....",
        "................",
    ],
    "grid": [
        "................",
        ".kkkkkkkkkkkkkk.",
        ".kwwwkwwwkwwwwk.",
        ".kwwwkwwwkwwwwk.",
        ".kwwwkwwwkwwwwk.",
        ".kkkkkkkkkkkkkk.",
        ".kwwwkrrrkwwwwk.",
        ".kwwwkrrrkwwwwk.",
        ".kwwwkrrrkwwwwk.",
        ".kkkkkkkkkkkkkk.",
        ".kwwwkwwwkbbbbk.",
        ".kwwwkwwwkbbbbk.",
        ".kwwwkwwwkbbbbk.",
        ".kwwwkwwwkbbbbk.",
        ".kkkkkkkkkkkkkk.",
        "................",
    ],
    "save": [
        "................",
        "................",
        "............kk..",
        "...........keek.",
        "..........keeek.",
        ".........keeek..",
        "..kk....keeek...",
        ".keek..keeek....",
        ".keeekkeeek.....",
        "..keeeeeeek.....",
        "...keeeeek......",
        "....keeek.......",
        ".....kek........",
        "......k.........",
        "................",
        "................",
    ],
    "close": [
        "................",
        "................",
        "..kk.......kk...",
        ".krrk.....krrk..",
        ".krrrk...krrrk..",
        "..krrrk.krrrk...",
        "...krrrkrrrk....",
        "....krrrrrk.....",
        "....krrrrrk.....",
        "...krrrkrrrk....",
        "..krrrk.krrrk...",
        ".krrrk...krrrk..",
        ".krrk.....krrk..",
        "..kk.......kk...",
        "................",
        "................",
    ],
    "resize": [
        "................",
        ".kkkkkk.........",
        ".kbbbbk.........",
        ".kbbkk..........",
        ".kbkbk..........",
        ".kbk.kbk........",
        ".kk...kbk.......",
        ".......kbk......",
        "........kbk...kk",
        ".........kbk.kbk",
        "..........kbkbk.",
        "...........kkbk.",
        "..........kbbbk.",
        ".........kkkkkk.",
        "................",
        "................",
    ],
    "new": [
        "................",
        "......kkkk......",
        "......keek......",
        "......keek......",
        "......keek......",
        "......keek......",
        ".kkkkkkeekkkkkk.",
        ".keeeeeeeeeeeek.",
        ".keeeeeeeeeeeek.",
        ".kkkkkkeekkkkkk.",
        "......keek......",
        "......keek......",
        "......keek......",
        "......keek......",
        "......kkkk......",
        "................",
    ],
    "draft": [
        "................",
        "..kkkkkkkkkk....",
        "..kwwwwwwwwkk...",
        "..kwggggwwwkwk..",
        "..kwwwwwwwwkkkk.",
        "..kwgggggwwwwwk.",
        "..kwwwwwwwwwwwk.",
        "..kwggggggwwwwk.",
        "..kwwwwwwwwwkkk.",
        "..kwgggwwwwkyk..",
        "..kwwwwwwwkyk...",
        "..kwwwwwwkyk....",
        "..kwwwwwklk.....",
        "..kwwwwwkkw.....",
        "..kkkkkkkkk.....",
        "................",
    ],
    "remove": [
        "................",
        "......kkkk......",
        ".....krrrrk.....",
        "..kkkkkkkkkkkk..",
        "..krrrrrrrrrrk..",
        "..kkkkkkkkkkkk..",
        "...krrRrrRrrrk..",
        "...krRrrRrrRk...",
        "...krRrrRrrRk...",
        "...krRrrRrrRk...",
        "...krRrrRrrRk...",
        "...krRrrRrrRk...",
        "...krRrrRrrRk...",
        "...krrrrrrrrk...",
        "....kkkkkkkk....",
        "................",
    ],
    "line": [
        "................",
        "............kkk.",
        "...........krrk.",
        "..........krrk..",
        ".........krrk...",
        "........krrk....",
        ".......krrk.....",
        "......krrk......",
        ".....krrk.......",
        "....krrk........",
        "...krrk.........",
        "..krrk..........",
        ".krrk...........",
        ".kkk............",
        "................",
        "................",
    ],
    "rect": [
        "................",
        "................",
        ".kkkkkkkkkkkkkk.",
        ".kBBBBBBBBBBBBk.",
        ".kBkkkkkkkkkkBk.",
        ".kBk........kBk.",
        ".kBk........kBk.",
        ".kBk........kBk.",
        ".kBk........kBk.",
        ".kBk........kBk.",
        ".kBk........kBk.",
        ".kBkkkkkkkkkkBk.",
        ".kBBBBBBBBBBBBk.",
        ".kkkkkkkkkkkkkk.",
        "................",
        "................",
    ],
    "pivot": [
        "................",
        ".....kkkkk......",
        "....kyyyyyk.....",
        "...kyywwyyyk....",
        "...kywwyyyyk....",
        "...kyyyyyyyk....",
        "...kyyyyyyyk....",
        "....kyyyyyk.....",
        ".....kyyyk......",
        "......kyk.......",
        "......kyk.......",
        ".......k........",
        "................",
        "................",
        "................",
        "................",
    ],
}


def main():
    os.makedirs(OUT, exist_ok=True)
    save(from_ascii(FRAME, WOOD), "frame")

    mission = from_ascii(FRAME, WOOD)
    star = [(12, 0), (11, 1), (12, 1), (13, 1), (10, 2), (11, 2), (12, 2), (13, 2), (14, 2),
            (11, 3), (12, 3), (13, 3), (11, 4), (13, 4)]
    for x, y in star:
        mission.putpixel((x + 1, y), hexcolor("#ffcc00"))
    for x, y in [(12, 2)]:
        mission.putpixel((x + 1, y), hexcolor("#fff3a0"))
    save(mission, "frame_mission")

    save(from_ascii(PAINTING, WOOD), "painting")

    save(Image.new("RGBA", (16, 16), (0, 0, 0, 0)), "blank")

    hover = Image.new("RGBA", (16, 16), (255, 255, 255, 70))
    for i in range(16):
        for p in [(i, 0), (i, 15), (0, i), (15, i)]:
            hover.putpixel(p, (255, 255, 255, 220))
    save(hover, "hover")

    bad = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    for i in range(8):
        bad.putpixel((i, i), hexcolor("#ff3030"))
        bad.putpixel((7 - i, i), hexcolor("#ff3030"))
        if i < 7:
            bad.putpixel((i + 1, i), hexcolor("#b01010"))
            bad.putpixel((6 - i, i), hexcolor("#b01010"))
    save(bad, "bad")

    for name, rows in ICONS.items():
        save(from_ascii(rows, ICON), "icon_" + name)
    edit = from_ascii(ICONS["pencil"], ICON)
    save(edit, "icon_edit")


if __name__ == "__main__":
    main()
