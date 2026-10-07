#!/usr/bin/env python3
"""Print the bounding box of .b3d meshes, in mesh units (10 units = 1 node
at visual_size 1). Used to fill the `height` field of the ANIMALS table in
init.lua. Rest pose only: bone animation is ignored.

Usage:  python3 tools/measure_models.py path/to/Model.b3d [...]
"""
import struct, sys, glob, os
def quat_rot(q, v):
    w,x,y,z = q
    # rotate v by quaternion
    ux,uy,uz = x,y,z
    vx,vy,vz = v
    # t = 2 * cross(u, v)
    tx = 2*(uy*vz-uz*vy); ty = 2*(uz*vx-ux*vz); tz = 2*(ux*vy-uy*vx)
    return (vx + w*tx + (uy*tz-uz*ty), vy + w*ty + (uz*tx-ux*tz), vz + w*tz + (ux*ty-uy*tx))
def parse(data):
    pts=[]
    def chunks(off, end):
        while off+8 <= end:
            tag = data[off:off+4].decode('latin1'); size = struct.unpack_from('<i', data, off+4)[0]
            yield tag, off+8, off+8+size
            off += 8+size
    def node(s, e, xf):
        # name
        n = data.index(b'\0', s); p = n+1
        pos = struct.unpack_from('<3f', data, p); scl = struct.unpack_from('<3f', data, p+12); rot = struct.unpack_from('<4f', data, p+24)
        p += 40
        def local(v):
            v = (v[0]*scl[0], v[1]*scl[1], v[2]*scl[2]); v = quat_rot(rot, v)
            return xf((v[0]+pos[0], v[1]+pos[1], v[2]+pos[2]))
        for tag, cs, ce in chunks(p, e):
            if tag == 'MESH':
                for t2, s2, e2 in chunks(cs+4, ce):
                    if t2 == 'VRTS':
                        flags, tcs, tcsz = struct.unpack_from('<3i', data, s2)
                        stride = 12 + (12 if flags & 1 else 0) + (16 if flags & 2 else 0) + 4*tcs*tcsz
                        q = s2+12
                        while q + stride <= e2:
                            pts.append(local(struct.unpack_from('<3f', data, q))); q += stride
            elif tag == 'NODE':
                node(cs, ce, local)
    for tag, s, e in chunks(12, len(data)):
        if tag == 'NODE': node(s, e, lambda v: v)
    return pts
for path in sys.argv[1:]:
    pts = parse(open(path,'rb').read())
    if not pts: print(os.path.basename(path), "no verts"); continue
    xs,ys,zs = zip(*pts)
    print("%-28s x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % (os.path.basename(path), min(xs),max(xs),min(ys),max(ys),min(zs),max(zs)))
