#!/usr/bin/env python3
"""Generate the Eco-CleanUp meshes (OBJ) and pixel-art textures.

Run from anywhere:  python3 tools/gen_assets.py
Outputs go to ../models and ../textures (relative to this script).
Waste meshes are authored in node units with the bottom at y=0; the entity
scales them with visual_size = 10. The bin mesh is a node mesh centred on the
node (y from -0.5).
"""
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "models")
TEXTURES = os.path.join(ROOT, "textures")
PREFIX = "skyss_cleanup_"


# ---------------------------------------------------------------- meshes

class Mesh:
    def __init__(self, atlas_w, atlas_h):
        self.v, self.vt, self.f = [], [], []
        self.aw, self.ah = atlas_w, atlas_h

    def vert(self, p):
        self.v.append(p)
        return len(self.v)

    def uv(self, px, py):
        # Pixel coordinates (origin top-left) -> OBJ UV (origin bottom-left).
        self.vt.append((px / self.aw, 1 - py / self.ah))
        return len(self.vt)

    def face(self, *pairs):
        self.f.append(pairs)

    def quad(self, corners, rect):
        """corners: 4 points counter-clockwise seen from outside, starting
        bottom-left. rect: (x0, y0, x1, y1) pixel rect on the atlas."""
        x0, y0, x1, y1 = rect
        uvs = [(x0, y1), (x1, y1), (x1, y0), (x0, y0)]
        self.face(*[(self.vert(c), self.uv(*u)) for c, u in zip(corners, uvs)])

    def box(self, lo, hi, rects):
        """Axis aligned box; rects keyed by +y -y +x -x +z -z."""
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        faces = {
            "+y": [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)],
            "-y": [(x0, y0, z1), (x1, y0, z1), (x1, y0, z0), (x0, y0, z0)],
            "+x": [(x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0)],
            "-x": [(x0, y0, z1), (x0, y0, z0), (x0, y1, z0), (x0, y1, z1)],
            "+z": [(x1, y0, z1), (x0, y0, z1), (x0, y1, z1), (x1, y1, z1)],
            "-z": [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)],
        }
        for key, corners in faces.items():
            if key in rects:
                self.quad(corners, rects[key])

    def frustum(self, bottom, top, y0, y1, rects):
        """Box whose bottom/top rectangles differ (tapered bin body).
        bottom/top: (half_x, half_z)."""
        bx, bz = bottom
        tx, tz = top
        b = {k: (sx * bx, y0, sz * bz) for k, sx, sz in
             [("a", -1, -1), ("b", 1, -1), ("c", 1, 1), ("d", -1, 1)]}
        t = {k: (sx * tx, y1, sz * tz) for k, sx, sz in
             [("a", -1, -1), ("b", 1, -1), ("c", 1, 1), ("d", -1, 1)]}
        sides = {
            "-z": [b["a"], b["b"], t["b"], t["a"]],
            "+x": [b["b"], b["c"], t["c"], t["b"]],
            "+z": [b["c"], b["d"], t["d"], t["c"]],
            "-x": [b["d"], b["a"], t["a"], t["d"]],
            "-y": [b["d"], b["c"], b["b"], b["a"]],
            "+y": [t["a"], t["b"], t["c"], t["d"]],
        }
        for key, corners in sides.items():
            if key in rects:
                self.quad(corners, rects[key])

    def lathe(self, profile, axis, center, segments, side_rect, caps):
        """Surface of revolution. profile: [(t, r)] with t increasing along
        the axis. The side rect is mapped with u = angle, v = t. caps: dict
        with optional 'start'/'end' pixel rects for flat discs."""
        t0, t1 = profile[0][0], profile[-1][0]
        sx0, sy0, sx1, sy1 = side_rect
        cx, cy, cz = center

        def point(t, r, ang):
            c, s = math.cos(ang) * r, math.sin(ang) * r
            if axis == "x":
                return (cx + t, cy + c, cz + s)
            return (cx + c, cy + t, cz + s)

        rings = []
        for t, r in profile:
            ring = []
            v = sy1 - (t - t0) / (t1 - t0) * (sy1 - sy0)
            for i in range(segments + 1):
                ang = 2 * math.pi * i / segments
                u = sx0 + (sx1 - sx0) * i / segments
                ring.append((self.vert(point(t, r, ang)), self.uv(u, v)))
            rings.append(ring)
        for a, b in zip(rings, rings[1:]):
            for i in range(segments):
                self.face(a[i], a[i + 1], b[i + 1], b[i])

        for key, idx in (("start", 0), ("end", -1)):
            rect = caps.get(key)
            if not rect:
                continue
            t, r = profile[idx]
            x0, y0, x1, y1 = rect
            mx, my = (x0 + x1) / 2, (y0 + y1) / 2
            hw, hh = (x1 - x0) / 2, (y1 - y0) / 2
            centre = (self.vert(point(t, 0, 0)), self.uv(mx, my))
            rim = []
            for i in range(segments):
                ang = 2 * math.pi * i / segments
                rim.append((self.vert(point(t, r, ang)),
                            self.uv(mx + math.cos(ang) * hw, my + math.sin(ang) * hh)))
            for i in range(segments):
                j = (i + 1) % segments
                if key == "start":
                    self.face(centre, rim[j], rim[i])
                else:
                    self.face(centre, rim[i], rim[j])

    def write(self, name):
        path = os.path.join(MODELS, PREFIX + name + ".obj")
        with open(path, "w") as fh:
            fh.write("# Generated by tools/gen_assets.py\n")
            for x, y, z in self.v:
                fh.write("v %.4f %.4f %.4f\n" % (x, y, z))
            for u, v in self.vt:
                fh.write("vt %.4f %.4f\n" % (u, v))
            fh.write("g main\n")
            for face in self.f:
                fh.write("f " + " ".join("%d/%d" % p for p in face) + "\n")


# ---------------------------------------------------------------- painting

def img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def hexc(code, a=255):
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def shade(c, f):
    return tuple(max(0, min(255, int(ch * f))) for ch in c[:3]) + (c[3],)


def paint_side(im, rect, total, bands, highlight=True):
    """Fill a lathe side strip. bands: [(t_from, t_to, colour or fn(u,row))]
    where t is the axial coordinate; rows run top (t=total) to bottom (t=0).
    A vertical highlight/shadow sweep fakes cylindrical lighting."""
    x0, y0, x1, y1 = rect
    h = y1 - y0
    w = x1 - x0
    for row in range(h):
        t = total * (1 - (row + 0.5) / h)
        for col in range(w):
            colour = None
            for a, b, c in bands:
                if a <= t <= b:
                    colour = c(col, row) if callable(c) else c
                    break
            if colour is None:
                continue
            if highlight:
                ang = 2 * math.pi * (col + 0.5) / w
                light = 0.78 + 0.32 * max(0, math.cos(ang - 0.6))
                if abs(((col + 0.5) / w) - 0.12) < 0.04:
                    light = 1.45  # specular streak
                colour = shade(colour, light)
            im.putpixel((x0 + col, y0 + row), colour)


def disc(im, rect, fill, rim=None, inner=None):
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = rect
    d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=fill)
    if rim:
        d.ellipse((x0, y0, x1 - 1, y1 - 1), outline=rim)
    if inner:
        inner(d, rect)


def save(im, name):
    im.save(os.path.join(TEXTURES, PREFIX + name + ".png"))


SIDE = (0, 0, 32, 24)
CAP_A = (0, 24, 8, 32)
CAP_B = (8, 24, 16, 32)


def plastic_bottle():
    L = 0.46
    profile = [(0.0, 0.07), (0.01, 0.085), (0.30, 0.085), (0.335, 0.07),
               (0.37, 0.036), (0.41, 0.036), (0.412, 0.046), (0.418, 0.046),
               (0.42, 0.042), (L, 0.042)]
    m = Mesh(32, 32)
    m.lathe(profile, "x", (-L / 2, 0.085, 0), 12, SIDE, {"start": CAP_A, "end": CAP_B})
    m.write("bottle")

    im = img(32, 32)
    clear = hexc("#a9dcf2", 170)
    label = lambda u, r: hexc("#2f7fd0") if (u // 4 + r) % 5 else hexc("#ffffff")
    paint_side(im, SIDE, L, [
        (0.0, 0.03, hexc("#8cc8e6", 190)),
        (0.03, 0.10, clear),
        (0.10, 0.20, label),
        (0.20, 0.335, clear),
        (0.335, 0.41, hexc("#bfe6f7", 160)),
        (0.41, L, hexc("#1d58b4")),
    ])
    disc(im, CAP_A, hexc("#8cc8e6", 200), rim=hexc("#5c9fc4"))
    disc(im, CAP_B, hexc("#1d58b4"), rim=hexc("#123d80"))
    save(im, "bottle_model")


def glass_bottle():
    L = 0.52
    profile = [(0.0, 0.085), (0.30, 0.09), (0.33, 0.08), (0.37, 0.04),
               (0.47, 0.034), (0.48, 0.042), (0.50, 0.042), (L, 0.036)]
    m = Mesh(32, 32)
    m.lathe(profile, "x", (-L / 2, 0.09, 0), 12, SIDE, {"start": CAP_A, "end": CAP_B})
    m.write("jar")

    im = img(32, 32)
    glass = hexc("#2f8a3f", 205)
    paint_side(im, SIDE, L, [
        (0.0, 0.08, glass),
        (0.08, 0.20, lambda u, r: hexc("#efe4c4") if r % 6 else hexc("#b9382f")),
        (0.20, 0.47, glass),
        (0.47, L, hexc("#1f6a2d", 230)),
    ])
    disc(im, CAP_A, hexc("#256f33", 220), rim=hexc("#174a21"))
    disc(im, CAP_B, hexc("#0e2a12"), rim=hexc("#2f8a3f"))
    save(im, "jar_model")


def can():
    L = 0.25
    profile = [(0.0, 0.058), (0.012, 0.066), (0.03, 0.066), (0.045, 0.062),
               (0.22, 0.062), (0.235, 0.066), (0.242, 0.066), (L, 0.056)]
    m = Mesh(32, 32)
    m.lathe(profile, "x", (-L / 2, 0.066, 0), 12, SIDE, {"start": CAP_A, "end": CAP_B})
    m.write("can")

    im = img(32, 32)
    silver = hexc("#c9ccd1")

    def body(u, r):
        wave = 9 + int(2.5 * math.sin(u / 32 * 2 * math.pi * 2))
        if wave <= r <= wave + 2:
            return hexc("#ffffff")
        if r in (4, 5) and u % 8 < 5:
            return hexc("#ffd43b")
        return hexc("#d62c2c")

    paint_side(im, SIDE, L, [(0.0, 0.045, silver), (0.045, 0.22, body), (0.22, L, silver)])

    def tab(d, rect):
        x0, y0, _, _ = rect
        d.rectangle((x0 + 3, y0 + 2, x0 + 4, y0 + 5), fill=hexc("#8d9096"))
    disc(im, CAP_A, silver, rim=hexc("#8d9096"))
    disc(im, CAP_B, silver, rim=hexc("#8d9096"), inner=tab)
    save(im, "can_model")


def barrel():
    L = 0.82
    r = 0.29
    profile = [(0.0, r - 0.01), (0.02, r), (0.18, r), (0.19, r + 0.012),
               (0.22, r + 0.012), (0.23, r), (0.59, r), (0.60, r + 0.012),
               (0.63, r + 0.012), (0.64, r), (0.80, r), (L, r - 0.01)]
    m = Mesh(32, 32)
    m.lathe(profile, "y", (0, 0, 0), 16, SIDE, {"start": CAP_A, "end": CAP_B})
    m.write("barrel")

    im = img(32, 32)
    rng = random.Random(7)
    rust = [(rng.randrange(32), rng.randrange(24), rng.randrange(2, 5)) for _ in range(9)]

    def paint(u, row):
        for cx, cy, rad in rust:
            if (u - cx) ** 2 + ((row - cy) * 1.4) ** 2 <= rad * rad:
                return hexc("#8a4b22") if (u + row) % 3 else hexc("#6a3516")
        return hexc("#3b6ea5") if (u // 2) % 6 else hexc("#33608f")

    ring = hexc("#2a4d74")
    paint_side(im, SIDE, L, [(0.0, 0.02, ring), (0.02, 0.18, paint),
                              (0.18, 0.23, ring), (0.23, 0.59, paint),
                              (0.59, 0.64, ring), (0.64, 0.80, paint),
                              (0.80, L, ring)])

    def bung(d, rect):
        x0, y0, _, _ = rect
        d.ellipse((x0 + 1, y0 + 1, x0 + 3, y0 + 3), fill=hexc("#1d3550"))
        d.point((x0 + 5, y0 + 5), fill=hexc("#8a4b22"))
        d.point((x0 + 6, y0 + 4), fill=hexc("#8a4b22"))
    disc(im, CAP_A, hexc("#2a4d74"))
    disc(im, CAP_B, hexc("#4a7fb6"), rim=hexc("#2a4d74"), inner=bung)
    save(im, "barrel_model")


def bag():
    m = Mesh(32, 32)
    rx, ry, rz = 0.30, 0.25, 0.27
    lat_n, lon_n = 8, 14
    rows = []
    for i in range(lat_n + 1):
        lat = -math.pi / 2 + math.pi * i / lat_n
        row = []
        for j in range(lon_n + 1):
            lon = 2 * math.pi * j / lon_n
            lump = 1 + 0.09 * math.sin(3 * lon + 1.3) * math.cos(2 * lat) \
                + 0.05 * math.cos(5 * lon) * math.sin(lat + 0.4)
            x = math.cos(lat) * math.cos(lon) * rx * lump
            z = math.cos(lat) * math.sin(lon) * rz * lump
            y = ry + math.sin(lat) * ry * lump
            y = max(y, 0.0)  # flattened where it rests on the ground
            u = 32 * j / lon_n
            v = 24 - 24 * i / lat_n
            row.append((m.vert((x, y, z)), m.uv(u, v)))
        rows.append(row)
    for a, b in zip(rows, rows[1:]):
        for j in range(lon_n):
            m.face(a[j], a[j + 1], b[j + 1], b[j])
    top = 2 * ry
    # Knot: a pinched neck and two tied flaps.
    top -= 0.05  # the lumpy shell peaks below 2 * ry
    m.lathe([(top - 0.04, 0.08), (top + 0.05, 0.03), (top + 0.08, 0.03), (top + 0.11, 0.055)], "y",
            (0, 0, 0), 8, (16, 24, 24, 32), {"end": (24, 24, 32, 32)})
    for s in (-1, 1):
        m.box((s * 0.07 - 0.045, top + 0.09, -0.015),
              (s * 0.07 + 0.045, top + 0.16, 0.015),
              {k: (16, 24, 24, 32) for k in ("+y", "+x", "-x", "+z", "-z")})
    m.write("bag")

    im = img(32, 32)
    for row in range(24):
        for col in range(32):
            base = hexc("#2b2e33")
            if (col * 7 + row * 3) % 11 == 0:
                base = hexc("#3d4249")
            if abs((col - 6) - row * 0.3) < 1.2 and 6 < row < 18:
                base = hexc("#68707a")  # shiny fold
            if row in (2, 3) and col % 9 < 4:
                base = hexc("#1b1d20")
            im.putpixel((col, row), base)
    d = ImageDraw.Draw(im)
    d.rectangle((16, 24, 31, 31), fill=hexc("#22252a"))
    d.line((16, 27, 23, 27), fill=hexc("#e8c547"))  # yellow drawstring
    save(im, "bag_model")


# ---------------------------------------------------------------- icons

def load_obj(path):
    verts, uvs, tris = [], [], []
    with open(path) as fh:
        for line in fh:
            p = line.split()
            if not p:
                continue
            if p[0] == "v":
                verts.append(tuple(map(float, p[1:4])))
            elif p[0] == "vt":
                uvs.append(tuple(map(float, p[1:3])))
            elif p[0] == "f":
                idx = [tuple(int(a) - 1 for a in q.split("/")) for q in p[1:]]
                for i in range(1, len(idx) - 1):
                    tris.append((idx[0], idx[i], idx[i + 1]))
    return verts, uvs, tris


def render_icon(name, yaw, pitch, size=32, margin=1.5):
    """Rasterise a waste mesh into a pixel-art inventory icon so the sprite
    matches the 3D model: nearest texel sampling, flat shading, outline."""
    verts, uvs, tris = load_obj(os.path.join(MODELS, PREFIX + name + ".obj"))
    tex = Image.open(os.path.join(TEXTURES, PREFIX + name + "_model.png")).convert("RGBA")
    tw, th = tex.size
    tp = tex.load()

    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))

    def view(v):
        x, y, z = v
        x, z = x * cy - z * sy, x * sy + z * cy
        y, z = y * cp - z * sp, y * sp + z * cp
        return x, y, z

    cam = [view(v) for v in verts]
    xs, ys = [c[0] for c in cam], [c[1] for c in cam]
    span = max(max(xs) - min(xs), max(ys) - min(ys))
    k = (size - 2 * margin) / span
    ox = size / 2 - (max(xs) + min(xs)) / 2 * k
    oy = size / 2 + (max(ys) + min(ys)) / 2 * k
    scr = [(ox + x * k, oy - y * k, z) for x, y, z in cam]

    light = (-0.35, 0.75, -0.55)
    ln = math.sqrt(sum(c * c for c in light))
    out = img(size, size)
    px = out.load()
    zbuf = [[1e9] * size for _ in range(size)]
    for (a, ta), (b, tb), (c, tc) in tris:
        A, B, C = scr[a], scr[b], scr[c]
        pa, pb, pc = cam[a], cam[b], cam[c]
        u = [pb[i] - pa[i] for i in range(3)]
        w = [pc[i] - pa[i] for i in range(3)]
        n = (u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0])
        nl = math.sqrt(sum(q * q for q in n)) or 1
        lit = 0.62 + 0.45 * abs(sum(n[i] * light[i] for i in range(3)) / nl / ln)
        den = (B[1] - C[1]) * (A[0] - C[0]) + (C[0] - B[0]) * (A[1] - C[1])
        if abs(den) < 1e-12:
            continue
        x0, x1 = max(0, int(min(A[0], B[0], C[0]))), min(size - 1, int(max(A[0], B[0], C[0])) + 1)
        y0, y1 = max(0, int(min(A[1], B[1], C[1]))), min(size - 1, int(max(A[1], B[1], C[1])) + 1)
        for yy in range(y0, y1 + 1):
            for xx in range(x0, x1 + 1):
                sx, sy_ = xx + 0.5, yy + 0.5
                l1 = ((B[1] - C[1]) * (sx - C[0]) + (C[0] - B[0]) * (sy_ - C[1])) / den
                l2 = ((C[1] - A[1]) * (sx - C[0]) + (A[0] - C[0]) * (sy_ - C[1])) / den
                l3 = 1 - l1 - l2
                if min(l1, l2, l3) < -1e-6:
                    continue
                z = l1 * A[2] + l2 * B[2] + l3 * C[2]
                if z >= zbuf[yy][xx]:
                    continue
                tu = l1 * uvs[ta][0] + l2 * uvs[tb][0] + l3 * uvs[tc][0]
                tv = l1 * uvs[ta][1] + l2 * uvs[tb][1] + l3 * uvs[tc][1]
                col = tp[min(tw - 1, max(0, int(tu * tw))), min(th - 1, max(0, int((1 - tv) * th)))]
                if col[3] < 20:
                    continue
                zbuf[yy][xx] = z
                # Translucent plastic/glass reads better opaque at icon size.
                px[xx, yy] = shade(col[:3] + (max(col[3], 235),), lit)

    # Dark outline taken from the neighbouring colour, like hand-drawn sprites.
    edge = {}
    for y in range(size):
        for x in range(size):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < size and 0 <= ny < size and px[nx, ny][3]:
                    edge[(x, y)] = shade(px[nx, ny][:3] + (255,), 0.32)
                    break
    for (x, y), c in edge.items():
        px[x, y] = c
    save(out, name)


ICON_VIEWS = {
    "bottle": (-35, 32),
    "jar": (-35, 32),
    "can": (-30, 30),
    "bag": (25, 22),
    "barrel": (25, 24),
}


def icons():
    for name, (yaw, pitch) in ICON_VIEWS.items():
        render_icon(name, yaw, pitch)


# ---------------------------------------------------------------- bins

BIN_COLOURS = {
    "plastic": ("#f2c230", "bottle"),
    "glass": ("#3f9b4e", "jar"),
    "general": ("#737a80", "bag"),
}


def bin_mesh():
    m = Mesh(64, 64)
    body_side = (0, 0, 32, 32)
    body_front = (32, 0, 64, 32)
    lid = (0, 32, 32, 48)
    lid_edge = (0, 48, 32, 52)
    dark = (32, 32, 40, 40)
    bottom = (40, 32, 48, 40)
    grey = (48, 32, 56, 40)
    m.frustum((0.38, 0.33), (0.43, 0.38), -0.40, 0.30,
              {"-z": body_front, "+z": body_side, "+x": body_side,
               "-x": body_side, "-y": bottom})
    m.box((-0.46, 0.30, -0.42), (0.46, 0.38, 0.42),
          {"+y": lid, "-y": dark, "+x": lid_edge, "-x": lid_edge,
           "+z": lid_edge, "-z": lid_edge})
    # Front handle and rear hinge.
    m.box((-0.25, 0.32, -0.47), (0.25, 0.36, -0.42),
          {k: grey for k in ("+y", "-y", "+x", "-x", "-z")})
    m.box((-0.40, 0.26, 0.38), (0.40, 0.32, 0.43),
          {k: dark for k in ("+y", "-y", "+x", "-x", "+z")})
    for sx in (-1, 1):
        for sz in (-1, 1):
            cx, cz = sx * 0.27, sz * 0.22
            m.box((cx - 0.05, -0.5, cz - 0.05), (cx + 0.05, -0.39, cz + 0.05),
                  {k: dark for k in ("+y", "+x", "-x", "+z", "-z", "-y")})
    m.write("bin")


def bin_texture(kind):
    colour, icon_name = BIN_COLOURS[kind]
    base = hexc(colour)
    im = img(64, 64)
    d = ImageDraw.Draw(im)
    # Body sides: vertical ribs and a darker base band.
    for x in range(32):
        for y in range(32):
            c = base
            if x % 8 in (0, 1):
                c = shade(base, 0.82)
            if y > 26:
                c = shade(base, 0.7)
            if y < 2:
                c = shade(base, 1.12)
            im.putpixel((x, y), c)
    # Front: same body plus a white plate carrying the waste icon.
    for x in range(32):
        for y in range(32):
            c = base if y <= 26 else shade(base, 0.7)
            if y < 2:
                c = shade(base, 1.12)
            im.putpixel((32 + x, y), c)
    d.rectangle((38, 5, 57, 24), fill=hexc("#f6f6f0"), outline=shade(base, 0.6))
    icon = Image.open(os.path.join(TEXTURES, PREFIX + icon_name + ".png")).convert("RGBA")
    icon = icon.resize((16, 16), Image.NEAREST)
    im.alpha_composite(icon, (40, 7))
    # Recycling arrows hint under the plate.
    for i, x in enumerate(range(41, 56, 5)):
        d.polygon([(x, 29), (x + 3, 29), (x + 1, 26)], fill=hexc("#ffffff"))
    # Lid: slightly darker with ridges.
    for x in range(32):
        for y in range(32, 52):
            c = shade(base, 0.9)
            if (y - 32) % 5 == 0 and y < 48:
                c = shade(base, 0.76)
            if y >= 48:
                c = shade(base, 0.68)
            im.putpixel((x, y), c)
    d.rectangle((32, 32, 39, 39), fill=hexc("#202224"))
    d.rectangle((40, 32, 47, 39), fill=shade(base, 0.5))
    d.rectangle((48, 32, 55, 39), fill=hexc("#b8bcc2"))
    save(im, "bin_" + kind)


# ---------------------------------------------------------------- misc

def particles():
    im = img(7, 7)
    d = ImageDraw.Draw(im)
    d.line((3, 0, 3, 6), fill=(255, 255, 255, 230))
    d.line((0, 3, 6, 3), fill=(255, 255, 255, 230))
    d.point((3, 3), fill=(255, 255, 255, 255))
    for p in ((2, 2), (4, 4), (2, 4), (4, 2)):
        d.point(p, fill=(255, 255, 255, 120))
    save(im, "sparkle")

    im = img(8, 8)
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, 7, 7), outline=(220, 245, 255, 220))
    d.point((2, 2), fill=(255, 255, 255, 255))
    save(im, "bubble")


def markers():
    for kind, colour in (("land", "#e08a2e"), ("water", "#2e8ae0")):
        im = img(16, 16)
        d = ImageDraw.Draw(im)
        d.ellipse((1, 1, 14, 14), outline=hexc(colour), width=2)
        d.line((4, 4, 11, 11), fill=hexc("#ffffff"), width=2)
        d.line((4, 11, 11, 4), fill=hexc("#ffffff"), width=2)
        save(im, "marker_" + kind)


def main():
    os.makedirs(MODELS, exist_ok=True)
    plastic_bottle()
    glass_bottle()
    can()
    barrel()
    bag()
    icons()
    bin_mesh()
    for kind in BIN_COLOURS:
        bin_texture(kind)
    particles()
    markers()


if __name__ == "__main__":
    main()
