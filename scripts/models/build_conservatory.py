"""Builds the conservatory walls from Wylie's side panel art (2026-11-23).

Usage: pip install trimesh shapely mapbox_earcut scipy
       python3 scripts/models/build_conservatory.py models/export/Conservatory.glb

Writes one glTF with five meshes, named for what the game sets on them:
WallFace (peach faces), WallDepth (brown wall tops, ends and reveals), Frame,
Glass (200, 255, 220 at 60% transparency) and Grille. The sign is not in the
mesh; the game adds it as text.

Measured from the 2048 px panel: 1201 px wide = 60 studs, so 1 px = 0.05 stud.
Local wall coords: x along the wall (-30..30), y up (0..22), z through the
wall (-1..1, +z outside)."""
import math, json, sys
import numpy as np, trimesh
from shapely.geometry import Polygon, box
from shapely.ops import unary_union

SEG = 20
WALL_LEN, WALL_H, WALL_T = 60.0, 22.0, 2.0
WIN_X = [-25.45, -18.0, -10.55, 10.55, 18.0, 25.45]
WIN_OUT_W, WIN_IN_W = 5.8, 4.8
WIN_BOTTOM_OUT, WIN_BOTTOM_IN = 1.3, 1.8
WIN_SPRING = 17.85            # where the arch starts
DOOR_OUT_W, DOOR_IN_W = 12.0, 10.4
DOOR_SPRING = 10.0
GRILLE_X = 0.95               # vertical bars either side of the window centre
GRILLE_Y = [5.8, 9.8, 13.85, 17.85]
BAR = 0.12

COL = {
    "WallFace": (243, 212, 158, 255),
    "WallDepth": (142, 90, 68, 255),
    "Frame": (226, 156, 122, 255),
    "Glass": (200, 255, 220, 102),   # 60% transparent
    "Grille": (142, 142, 142, 255),
}

def arch(cx, width, bottom, spring):
    r = width / 2
    pts = [(cx - r, bottom), (cx + r, bottom), (cx + r, spring)]
    for i in range(1, SEG):
        a = math.pi * i / SEG
        pts.append((cx + r * math.cos(a), spring + r * math.sin(a)))
    pts.append((cx - r, spring))
    return Polygon(pts)

def extrude(poly, z0, z1):
    m = trimesh.creation.extrude_polygon(poly, z1 - z0)
    m.apply_translation((0, 0, z0))
    return m

def split_faces(mesh):
    """Front and back faces (normal along z) vs the rest."""
    n = mesh.face_normals
    flat = np.abs(n[:, 2]) > 0.99
    a = mesh.submesh([np.where(flat)[0]], append=True)
    b = mesh.submesh([np.where(~flat)[0]], append=True)
    return a, b

def wall():
    parts = {k: [] for k in COL}
    slab = box(-WALL_LEN / 2, 0, WALL_LEN / 2, WALL_H)
    holes = [arch(x, WIN_OUT_W, WIN_BOTTOM_OUT, WIN_SPRING) for x in WIN_X]
    door_out = arch(0, DOOR_OUT_W, -1, DOOR_SPRING)
    slab = slab.difference(unary_union(holes + [door_out]))
    face, depth = split_faces(extrude(slab, -WALL_T / 2, WALL_T / 2))
    parts["WallFace"].append(face); parts["WallDepth"].append(depth)
    # Window frames, glass and grille.
    for x in WIN_X:
        outer = arch(x, WIN_OUT_W, WIN_BOTTOM_OUT, WIN_SPRING)
        inner = arch(x, WIN_IN_W, WIN_BOTTOM_IN, WIN_SPRING)
        f, d = split_faces(extrude(outer.difference(inner), -1.1, 1.1))
        parts["Frame"].append(f); parts["WallDepth"].append(d)
        parts["Glass"].append(extrude(inner, -0.05, 0.05))
        bars = []
        for gx in (-GRILLE_X, GRILLE_X):
            bars.append(box(x + gx - BAR / 2, WIN_BOTTOM_IN, x + gx + BAR / 2, WIN_SPRING))
        for gy in GRILLE_Y:
            bars.append(box(x - WIN_IN_W / 2, gy - BAR / 2, x + WIN_IN_W / 2, gy + BAR / 2))
        # Small arch over the middle pane and two rays to the big arch.
        small = arch(x, 2 * GRILLE_X + BAR, WIN_SPRING, WIN_SPRING).exterior
        ring = small.buffer(BAR / 2, quad_segs=2)
        bars.append(ring.intersection(box(x - 2, WIN_SPRING, x + 2, WIN_SPRING + 2)))
        for side in (-1, 1):
            a = math.radians(60)
            p0 = (x + side * GRILLE_X * math.cos(a), WIN_SPRING + GRILLE_X * math.sin(a))
            r = WIN_IN_W / 2
            p1 = (x + side * r * math.cos(a), WIN_SPRING + r * math.sin(a))
            from shapely.geometry import LineString
            bars.append(LineString([p0, p1]).buffer(BAR / 2, cap_style=2, quad_segs=2))
        grille = unary_union(bars).intersection(inner)
        parts["Grille"].append(extrude(grille, -0.12, 0.12))
    # Door frame (a U shape, open at the floor).
    door_in = arch(0, DOOR_IN_W, -1, DOOR_SPRING)
    door_frame = arch(0, DOOR_OUT_W, 0, DOOR_SPRING).difference(door_in)
    f, d = split_faces(extrude(door_frame, -1.1, 1.1))
    parts["Frame"].append(f); parts["WallDepth"].append(d)
    return {k: trimesh.util.concatenate(v) for k, v in parts.items() if v}

def building():
    one = wall()
    out = {k: [] for k in COL}
    for i in range(4):
        rot = trimesh.transformations.rotation_matrix(math.radians(90 * i), (0, 1, 0))
        move = trimesh.transformations.translation_matrix((0, 0, 29))
        for k, m in one.items():
            c = m.copy(); c.apply_transform(move); c.apply_transform(rot); out[k].append(c)
    # Corner posts hide where the walls meet.
    for sx in (-1, 1):
        for sz in (-1, 1):
            # Peach sides like the wall faces, brown top like the wall tops.
            post = trimesh.creation.box((2.04, WALL_H + 0.02, 2.04))
            post.apply_translation((sx * 29, WALL_H / 2 + 0.01, sz * 29))
            up = post.face_normals[:, 1] > 0.99
            out["WallFace"].append(post.submesh([np.where(~up)[0]], append=True))
            out["WallDepth"].append(post.submesh([np.where(up)[0]], append=True))
    return {k: trimesh.util.concatenate(v) for k, v in out.items()}

if __name__ == "__main__":
    meshes = building()
    scene = trimesh.Scene()
    info = {}
    for name, m in meshes.items():
        m.merge_vertices()
        r, g, b, a = COL[name]
        mat = trimesh.visual.material.PBRMaterial(
            name=name, baseColorFactor=[r / 255, g / 255, b / 255, a / 255],
            alphaMode="BLEND" if a < 255 else "OPAQUE", metallicFactor=0, roughnessFactor=0.8,
            doubleSided=name == "Glass")
        m.visual = trimesh.visual.TextureVisuals(material=mat)
        scene.add_geometry(m, node_name=name, geom_name=name)
        info[name] = {"triangles": int(len(m.faces)), "size": [round(float(v), 2) for v in m.extents]}
    out = sys.argv[1]
    scene.export(out)
    print(json.dumps(info, indent=1))
