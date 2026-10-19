#!/usr/bin/env python3
"""The player on the world map: a yellow arrow pointing where they look.

Writes textures/classrooms_bridge_map_me_<k>.png, 16 directions
counter-clockwise from north like the Luanti yaw (k * 22.5 degrees).
"""
import math
import os

from PIL import Image, ImageDraw

TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "textures")
DIRS = 16
BIG, OUT = 256, 32  # drawn large, then scaled down for smooth edges


def arrow(k):
    img = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    a = math.radians(k * 360 / DIRS)
    c = BIG / 2
    u = BIG / 64

    def rot(x, y):
        # x right, y up (north); counter-clockwise by a
        rx = x * math.cos(a) - y * math.sin(a)
        ry = x * math.sin(a) + y * math.cos(a)
        return c + rx * u, c - ry * u

    def shape(tip, side, back, notch):
        return [rot(0, tip), rot(side, -back), rot(0, -notch), rot(-side, -back)]

    # dark outline, white rim, yellow arrow with a notch
    d.polygon(shape(30, 22, 24, 12), fill=(30, 30, 40))
    d.polygon(shape(25, 17, 19, 9), fill=(255, 255, 255))
    d.polygon(shape(20, 12, 14, 6), fill=(255, 212, 59))
    return img.resize((OUT, OUT), Image.LANCZOS)


if __name__ == "__main__":
    for k in range(DIRS):
        arrow(k).save(os.path.join(TEX, f"classrooms_bridge_map_me_{k}.png"))
