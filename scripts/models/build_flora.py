"""Builds the Flora statue for the conservatory: Flora, Roman goddess of
flowers, as a cartoony marble statue on a pedestal with FLORA on a panel.

Wylie's brief (2026-11-26): cartoony (green cartoon statue reference) but
made of marble; she holds or is wreathed in flowers; she stands on a
pedestal with "FLORA" written on a panel. Pose and flowers follow the white
Flora reference: long robe blowing to one side, head tilted up, a wreath of
roses in her hair, a garland of roses down one side, a bunch of roses in
each hand, a rose brooch, roses round her feet.

Usage (from the repo root):
  python3 scripts/models/build_flora.py models/statues/Flora.glb

Sizes are in studs. The pedestal stands on the origin; Flora stands on its
top (PEDESTAL_TOP). Cartoon proportions: the head is about a quarter of her
height. The statue is built about 9.4 units tall and scaled at the end so
that, with the pedestal, it is TOTAL_HEIGHT studs tall (14, Wylie round 3).

Parts (one MeshPart each in Studio):
  Marble    Flora and her hair (off-white marble)
  Flowers, Flowers2  her roses and leaves, split in two (the same marble;
            own parts so no part passes 20,000 triangles)
  Pedestal  the pedestal and its panel (a slightly greyer marble)
  Letters   FLORA on the panel (dark, like carved and filled letters)
  Veins     light grey marble veins on the pedestal and the robe
  Outline   black keyline round Flora and the pedestal, plus face and fold
            lines (delete it, and OutlineFlowers, for the plain look)
  OutlineFlowers, OutlineFlowers2  keyline round the flowers and leaves,
            and the rose spirals
"""
import math
import sys

import numpy as np
import trimesh

import creature_kit as kit

MARBLE = (243, 240, 232, 255)
PEDESTAL = (226, 223, 216, 255)
LETTERS = (66, 66, 74, 255)
VEINS = (190, 188, 196, 255)
BLACK = (0, 0, 0, 255)

OUTLINE = 0.045          # keyline thickness on the big shapes, studs
OUTLINE_SMALL = 0.022    # on flowers, leaves and the face
LINE = 0.024             # radius of drawn lines (face, folds, rose spirals)
VEIN = 0.022             # radius of a marble vein

PEDESTAL_TOP = 3.2       # in build units, before scaling to TOTAL_HEIGHT
TOTAL_HEIGHT = 14.0      # studs, pedestal base to the top of her bun (Wylie, round 3)
ROSE_SCALE = 1.35        # all roses, so they read from a distance
HEAD_TILT = 14           # degrees, face turned up like the reference
FOLDS = 9                # folds round the robe

rng = np.random.default_rng(7)
marble, pedestal, letters, veins, outline = [], [], [], [], []
flowers, flower_lines = [], []   # kept as their own parts, so no part passes 20,000 triangles


def add(m, t=OUTLINE, to=None, lines_to=None):
    (marble if to is None else to).append(m)
    (outline if lines_to is None else lines_to).append(kit.outline_shell(m, t))
    return m


def line(points, r=LINE, to=None):
    pts = np.asarray(points, float)
    up = (0, 1, 0)
    t = pts[-1] - pts[0]
    if abs(t[1]) > 0.9 * np.linalg.norm(t):
        up = (1, 0, 0)
    (outline if to is None else to).append(kit.sweep(pts, [r] * len(pts), [r] * len(pts), sections=5, up=up))


def transform(points, matrix):
    pts = np.asarray(points, float)
    return pts @ matrix[:3, :3].T + matrix[:3, 3]


def box(lo, hi):
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    m = trimesh.creation.box(extents=hi - lo)
    m.apply_translation((lo + hi) / 2)
    return m


# ---------------------------------------------------------------- pedestal

DIE = 1.7                # half width of the pedestal's main block
DIE_LO, DIE_HI = 0.7, 2.7
PANEL_W = 2.84           # FLORA fits inside 78% of this, so it never touches the plaque edge


def build_pedestal():
    for lo, hi in [((-2.2, 0, -2.2), (2.2, 0.4, 2.2)),
                   ((-2.0, 0.4, -2.0), (2.0, 0.7, 2.0)),
                   ((-DIE, DIE_LO, -DIE), (DIE, DIE_HI, DIE)),
                   ((-1.9, 2.7, -1.9), (1.9, 2.95, 1.9)),
                   ((-2.05, 2.95, -2.05), (2.05, PEDESTAL_TOP, 2.05))]:
        add(box(lo, hi), OUTLINE, to=pedestal)
    # Raised panel on the front (-Z) face, with FLORA on it.
    add(box((-PANEL_W / 2, 1.15, -DIE - 0.07), (PANEL_W / 2, 2.3, -DIE + 0.05)), 0.03, to=pedestal)
    letters.append(flora_text(centre_y=1.72, face_z=-DIE - 0.07, height=0.6, depth=0.06,
                              max_width=PANEL_W * 0.78))
    pedestal_veins()


def flora_text(centre_y, face_z, height, depth, max_width):
    """FLORA as raised letters, read from the front (-Z)."""
    from matplotlib.font_manager import FontProperties
    from matplotlib.textpath import TextPath
    from shapely.geometry import Polygon
    from shapely.ops import unary_union

    path = TextPath((0, 0), "FLORA", size=1.0,
                    prop=FontProperties(family="DejaVu Serif", weight="bold"))
    rings = [Polygon(p) for p in path.to_polygons() if len(p) > 2]
    rings = [r.buffer(0) for r in rings if r.area > 1e-6]
    # Outer outlines contain the holes (the middles of O, R, A).
    outers = [r for r in rings if not any(o is not r and o.contains(r) for o in rings)]
    shapes = []
    for o in outers:
        holes = [r for r in rings if r is not o and o.contains(r)]
        shapes.append(o.difference(unary_union(holes)) if holes else o)
    meshes = [trimesh.creation.extrude_polygon(s, depth) for s in shapes]
    m = trimesh.util.concatenate(meshes)
    lo, hi = m.bounds
    scale = min(height / (hi[1] - lo[1]), max_width / (hi[0] - lo[0]))
    m.apply_translation([-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, 0])
    m.apply_scale([scale, scale, 1])
    # Turn to face -Z: (x, y, z) -> (-x, y, -z), then onto the panel.
    m.apply_transform(trimesh.transformations.rotation_matrix(math.pi, (0, 1, 0)))
    m.apply_translation([0, centre_y, face_z])
    return m


def wander(n, start, end, wobble):
    """A gently wandering line from start to end (2D), like a marble vein."""
    t = np.linspace(0, 1, n)[:, None]
    pts = np.asarray(start) * (1 - t) + np.asarray(end) * t
    d = np.asarray(end, float) - np.asarray(start)
    side = np.array([-d[1], d[0]]) / np.linalg.norm(d)
    phase = rng.uniform(0, 6.3, 3)
    off = (np.sin(t * 7 + phase[0]) * 0.5 + np.sin(t * 13 + phase[1]) * 0.3
           + np.sin(t * 23 + phase[2]) * 0.2) * wobble * np.sin(math.pi * t)
    return pts + off * side


def pedestal_veins():
    faces = [  # (outward normal, across axis)
        ((0, 0, -1), (1, 0, 0)), ((0, 0, 1), (1, 0, 0)),
        ((1, 0, 0), (0, 0, 1)), ((-1, 0, 0), (0, 0, 1))]
    for k, (n, a) in enumerate(faces):
        n, a = np.asarray(n, float), np.asarray(a, float)
        lines = [((-1.7, 0.95), (1.7, 1.0))] if k == 0 else \
                [((-1.7, rng.uniform(1.6, 2.5)), (1.7, rng.uniform(0.8, 1.6))),
                 ((rng.uniform(-1.2, 0.2), 0.7), (1.7, rng.uniform(1.8, 2.6)))]
        if k == 0:  # front: one vein under the panel and one over it
            lines.append(((-1.7, 2.45), (0.6, 2.7)))
        for s, e in lines:
            pts2 = wander(24, s, e, 0.35)
            pts2[:, 0] = np.clip(pts2[:, 0], -DIE, DIE)
            pts2[:, 1] = np.clip(pts2[:, 1], DIE_LO + 0.02, DIE_HI - 0.02)
            pts = [n * DIE + a * u + np.array([0, v, 0]) for u, v in pts2]
            line(pts, VEIN, to=veins)
    # A couple on the top slab's sides too.
    for z in (-2.05, 2.05):
        pts2 = wander(16, (-2.0, 3.0), (1.2, 3.15), 0.08)
        line([(u, v, z) for u, v in pts2], VEIN, to=veins)


# ------------------------------------------------------------------- robe

PROFILE = [(1.12, 0.0), (1.08, 0.3), (0.98, 0.9), (0.86, 1.6), (0.74, 2.3), (0.66, 2.8),
           (0.58, 3.25), (0.6, 3.6), (0.64, 3.85), (0.6, 4.05), (0.48, 4.22), (0.25, 4.32),
           (0.02, 4.36)]


def robe_point(theta, y, lift=0.0):
    """A point on the robe at angle theta (front is -pi/2) and height y
    (above the pedestal top), lifted off the cloth."""
    ys = [p[1] for p in PROFILE]
    r = float(np.interp(y, ys, [p[0] for p in PROFILE]))
    zs = float(np.interp(y, [0, 2.0, 3.0, 4.4], [0.88, 0.8, 0.7, 0.62]))
    amp = float(np.interp(y, [0, 1.0, 2.6, 3.2], [0.09, 0.07, 0.035, 0.0]))
    r = r * (1 + amp * math.sin(FOLDS * theta + 0.5)) + lift
    sway = 0.0   # Wylie: base centred on the pedestal (was blown out to +X)
    return np.array([r * math.cos(theta) + sway, y + PEDESTAL_TOP, r * math.sin(theta) * zs])


def robe():
    nt, ys = 72, np.linspace(0, PROFILE[-1][1], 40)
    thetas = np.linspace(0, 2 * math.pi, nt, endpoint=False)
    verts = [robe_point(t, y) for y in ys for t in thetas]
    verts += [np.array([0.0, PEDESTAL_TOP, 0]), np.array([0, PEDESTAL_TOP + PROFILE[-1][1], 0])]
    faces = []
    for j in range(len(ys) - 1):
        for i in range(nt):
            a, b = j * nt + i, j * nt + (i + 1) % nt
            faces += [[a, b + nt, b], [a, a + nt, b + nt]]
    bot, top = len(verts) - 2, len(verts) - 1
    for i in range(nt):
        faces.append([bot, i, (i + 1) % nt])
        faces.append([top, (len(ys) - 1) * nt + (i + 1) % nt, (len(ys) - 1) * nt + i])
    m = trimesh.Trimesh(np.array(verts), np.array(faces))
    m.fix_normals()
    add(m)
    # Fold lines down the valleys between the folds.
    for k in range(FOLDS):
        th = (-math.pi / 2 - 0.5 + 2 * math.pi * k) / FOLDS
        top_y = rng.uniform(1.3, 2.6)
        line([robe_point(th, y, 0.005) for y in np.linspace(0.08, top_y, 14)])
    # A high belt under the bust.
    belt = [robe_point(t, 3.42, 0.03) for t in np.linspace(0, 2 * math.pi, 41)]
    add(kit.sweep(belt, [0.06] * 41, [0.05] * 41, sections=8), OUTLINE_SMALL)
    # Marble veins on the robe.
    for th0, y0, y1 in [(-1.2, 0.2, 2.5), (-2.4, 0.5, 3.1), (0.6, 0.2, 2.2), (2.2, 0.8, 3.0)]:
        ph = rng.uniform(0, 6)
        pts = [robe_point(th0 + 0.25 * math.sin(2.1 * y + ph) + 0.08 * math.sin(5.3 * y), y, 0.004)
               for y in np.linspace(y0, y1, 30)]
        line(pts, VEIN * 0.9, to=veins)


# ------------------------------------------------------------- flowers

def spiral_ball(radii, turns=1.7, open_share=0.88):
    """A ball (radii x, y, z) with a cartoon spiral drawn on its top, like a
    rose seen from above or a hair bun. Returns (ball, spiral line)."""
    rx, ry, rz = radii
    ball = kit.ellipsoid((0, 0, 0), radii, rings=6, segments=10)
    pts = []
    spin = rng.uniform(0, 6.3)
    for t in np.linspace(0, 1, 20):
        a = spin + t * turns * 2 * math.pi
        rho = open_share * (1 - t) ** 0.85 + 0.06
        x, z = rho * math.cos(a), rho * math.sin(a)
        y = math.sqrt(max(0.0, 1 - rho * rho)) + 0.03
        pts.append((x * rx, y * ry, z * rz))
    w = max(LINE * 0.7, min(rx, rz) * 0.09)
    spiral = kit.sweep(pts, [w] * len(pts), [w] * len(pts), sections=4, up=(0, 1, 0))
    return ball, spiral


def place(m, centre, facing):
    m = m.copy()
    f = np.asarray(facing, float)
    m.apply_transform(trimesh.geometry.align_vectors([0, 1, 0], f / np.linalg.norm(f)))
    m.apply_translation(centre)
    return m


def rose(centre, size, facing):
    """A cartoon rose: a bud with a spiral on top, cupped by five petals, so
    it reads as a flower and not as a curl of hair."""
    size *= ROSE_SCALE
    ball, spiral = spiral_ball((size, size * 0.72, size))
    add(place(ball, centre, facing), OUTLINE_SMALL, flowers, flower_lines)
    flower_lines.append(place(spiral, centre, facing))
    spin = rng.uniform(0, 6.3)
    for k in range(5):
        a = spin + 2 * math.pi * k / 5
        petal = kit.ellipsoid((0, 0, 0), (size * 0.62, size * 0.2, size * 0.5), rings=4, segments=8)
        petal.apply_transform(trimesh.transformations.rotation_matrix(math.radians(32), (0, 0, 1)))
        petal.apply_translation((size * 0.88, -size * 0.32, 0))
        petal.apply_transform(trimesh.transformations.rotation_matrix(a, (0, 1, 0)))
        add(place(petal, centre, facing), OUTLINE_SMALL * 0.8, flowers, flower_lines)


def leaf(base, direction, length, width, up=(0, 1, 0)):
    d = np.asarray(direction, float)
    d /= np.linalg.norm(d)
    up = np.asarray(up, float)
    across = np.cross(d, up)
    across /= np.linalg.norm(across)
    inner = np.cross(across, d)
    t = np.linspace(0, 1, 6)
    length *= 0.9
    spine = [np.asarray(base) + d * length * s - inner * 0.12 * length * s * s for s in t]
    widths = width * 1.6 * np.array([0.45, 0.95, 1.0, 0.8, 0.45, 0.08])
    m = kit.blade(spine, [across] * 6, [inner] * 6, widths, fold=0.2, thickness=0.03)
    add(m, OUTLINE_SMALL * 0.8, flowers, flower_lines)


def bunch(centre, side):
    """A bunch of roses held at the hip, resting on the forearm."""
    c = np.asarray(centre, float)
    rose(c + (0, 0.16, 0), 0.17, (0.15 * side, 1, -0.4))
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.4
        off = np.array([math.cos(a) * 0.27, 0.0, math.sin(a) * 0.24])
        rose(c + off + (0, 0.02, 0), 0.15, off * 2.2 + (0, 1, -0.3))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 1.0
        d = np.array([math.cos(a), -0.4, math.sin(a)])
        leaf(c + d * 0.25, d, 0.32, 0.17)


# ------------------------------------------------------------- body

SHOULDER = np.array([0.56, PEDESTAL_TOP + 4.05, 0.0])
ELBOW = np.array([0.92, PEDESTAL_TOP + 3.05, 0.1])
HAND = np.array([1.12, PEDESTAL_TOP + 2.6, -0.42])


def arms():
    for sx in (1, -1):
        m = np.diag([sx, 1, 1])
        s, e, h = SHOULDER @ m, ELBOW @ m, HAND @ m
        add(kit.ellipsoid(s + (0, 0.02, 0), (0.27, 0.24, 0.26)))
        # Loose sleeve to the elbow, flaring out.
        pts = [s + (e - s) * t for t in np.linspace(0.05, 1.0, 9)]
        w = list(np.linspace(0.2, 0.33, 9))
        add(kit.sweep(pts, w, w, sections=12, up=(0, 0, 1)))
        # Bare forearm and hand.
        pts = [e + (h - e) * t for t in np.linspace(-0.1, 1.0, 8)]
        w = list(np.linspace(0.16, 0.13, 8))
        add(kit.sweep(pts, w, w, sections=10, up=(0, 1, 0)))
        add(kit.ellipsoid(h + (0.02 * sx, 0, -0.05), (0.15, 0.13, 0.18)))
        bunch(h + (0.04 * sx, 0.12, -0.02), sx)


def feet():
    # One bare foot peeks out under the hem at the front.
    foot = kit.ellipsoid((0, 0, 0), (0.16, 0.1, 0.3))
    foot.apply_transform(trimesh.transformations.rotation_matrix(math.radians(-12), (0, 1, 0)))
    foot.apply_translation((-0.28, PEDESTAL_TOP + 0.09, -0.95))
    add(foot, OUTLINE_SMALL)
    for k in range(4):   # toe lines
        x = -0.28 - 0.1 + k * 0.065 + 0.02
        line([(x + 0.05, PEDESTAL_TOP + 0.09, -1.2), (x + 0.06, PEDESTAL_TOP + 0.17, -1.17)], LINE * 0.7)


def brooch():
    p = robe_point(-math.pi / 2, 3.85, 0.04)
    rose(p, 0.12, (0, 0.25, -1))


# ------------------------------------------------------------- head

NECK = np.array([0.0, PEDESTAL_TOP + 4.1, 0.0])
PIVOT = np.array([0.0, PEDESTAL_TOP + 4.65, 0.0])
HEAD_C = np.array([0.0, PEDESTAL_TOP + 5.3, -0.04])
HEAD_R = np.array([0.66, 0.72, 0.66])
TILT = trimesh.transformations.rotation_matrix(math.radians(HEAD_TILT), (1, 0, 0), PIVOT)


def on_head(u, v, lift=0.0, scale=1.0):
    """Point on the (untilted) head: u degrees round from the front towards
    +X, v degrees up from the middle, lifted off the skin."""
    u, v = math.radians(u), math.radians(v)
    d = np.array([math.sin(u) * math.cos(v), math.sin(v), -math.cos(u) * math.cos(v)])
    r = HEAD_R * scale
    p = d / math.sqrt(np.sum((d / r) ** 2))
    n = p / r ** 2
    n /= np.linalg.norm(n)
    return HEAD_C + p + n * lift


def head():
    m = []   # untilted head meshes, tilted together at the end
    o = []
    lines = []
    face = kit.ellipsoid(HEAD_C, HEAD_R, rings=14, segments=22)
    m.append(face)
    # Nose.
    nose = kit.ellipsoid(on_head(0, -6, 0.04), (0.075, 0.13, 0.09), rings=6, segments=10)
    m.append(nose)
    # Closed, peaceful eyes (curves bowing down) with a lash at the outer end, and brows.
    for sx in (1, -1):
        lines.append([on_head(sx * u, 6 - 7 * math.sin(math.pi * (u - 13) / 26), 0.01)
                      for u in np.linspace(13, 39, 12)])
        lines.append([on_head(sx * 38, 5, 0.01), on_head(sx * 44, 1, 0.01)])
        lines.append([on_head(sx * u, 20 + 4 * math.sin(math.pi * (u - 10) / 34), 0.01)
                      for u in np.linspace(10, 44, 12)])
    # Small smile.
    lines.append([on_head(u, -27 - 5 * math.sin(math.pi * (u + 13) / 26), 0.01)
                  for u in np.linspace(-13, 13, 12)])
    # Hair: a cap over the top and back, cut off along the hairline.
    cap = kit.ellipsoid(HEAD_C + (0, 0.05, 0.07), HEAD_R * 1.08, rings=14, segments=22)
    n = np.array([0, 0.62, 1.0])
    cap = cap.slice_plane(HEAD_C + (0, 0.35, -0.33), n / np.linalg.norm(n), cap=True)
    m.append(cap)
    # Hair strand lines from the hairline over the top.
    for u in (-70, -45, -20, 5, 30, 55, 75):
        lines.append([on_head(u + 8 * math.sin(math.radians(v * 3)), v, 0.06, 1.0)
                      for v in np.linspace(48, 84, 8)])
    # Curls framing the face, each with a spiral like the cartoon reference.
    for sx in (1, -1):
        for u, v, r in [(48, 50, 0.17), (64, 32, 0.18), (74, 10, 0.18), (76, -12, 0.17), (72, -33, 0.15)]:
            p = on_head(sx * u, v, 0.06)
            ball, spiral = spiral_ball((r, r * 0.7, r), turns=1.6)
            m.append(place(ball, p, p - HEAD_C))
            o.append(place(spiral, p, p - HEAD_C))
    # Long hair down the back.
    m.append(kit.ellipsoid(HEAD_C + (0, -0.45, 0.36), (0.6, 0.72, 0.32)))
    # Bun on top at the back, with a spiral like the cartoon reference.
    ball, spiral = spiral_ball((0.3, 0.24, 0.28), turns=2.0)
    bun_c, bun_f = HEAD_C + (0, 0.66, 0.34), (0, 1, 0.8)
    m.append(place(ball, bun_c, bun_f))
    o.append(place(spiral, bun_c, bun_f))

    head_meshes = []
    for mesh in m:
        mesh = mesh.copy()
        mesh.apply_transform(TILT)
        head_meshes.append(mesh)
        add(mesh, OUTLINE if mesh is not nose else OUTLINE_SMALL)
    for mesh in o:
        mesh.apply_transform(TILT)
        outline.append(mesh)
    for pts in lines:
        line(transform(pts, TILT), LINE * 0.9)

    # Neck.
    add(kit.sweep([NECK, PIVOT + (0, 0.25, 0.02)], [0.22, 0.2], [0.2, 0.19], sections=12, up=(0, 0, 1)))

    # Wreath of roses round the head, high at the forehead, lower behind.
    wc = HEAD_C + (0, 0.28, 0.1)
    tilt = trimesh.transformations.rotation_matrix(math.radians(22), (1, 0, 0))[:3, :3]
    wreath = []
    for k in range(11):
        a = 2 * math.pi * k / 11 + math.pi / 2 + 0.29   # start at the front
        p = wc + tilt @ np.array([0.72 * math.cos(a), 0, 0.72 * math.sin(a)])
        wreath.append((transform([p], TILT)[0], transform([wc], TILT)[0]))
    for k, (p, c) in enumerate(wreath):
        out = p - c
        rose(p, 0.15 if k % 2 else 0.13, out / np.linalg.norm(out) + (0, 0.7, 0))
        q = wreath[(k + 1) % len(wreath)][0]
        mid = (p + q) / 2
        d = (mid - c)
        d = d / np.linalg.norm(d) + (0, -0.2, 0)
        leaf(mid, d, 0.24, 0.13)

    # Wavy locks over the back of the shoulders.
    for sx in (1, -1):
        start = transform([HEAD_C + (sx * 0.48, -0.15, 0.25)], TILT)[0]
        pts = [start + (sx * (0.05 + 0.06 * math.sin(t * 9)), -1.15 * t, 0.12 * t) for t in np.linspace(0, 1, 14)]
        w = list(np.linspace(0.2, 0.09, 14))
        add(kit.sweep(pts, w, w, sections=10, up=(0, 0, 1)))
    return wreath


def garland(wreath):
    """A garland of roses from the wreath, over her right shoulder and down
    the outside of her arm to the bunch in her hand (+X side)."""
    start = wreath[3][0]
    pts = np.array([start, (0.85, PEDESTAL_TOP + 4.55, 0.2), SHOULDER + (0.3, 0.2, 0.05),
                    ELBOW + (0.3, 0.15, 0.0), HAND + (0.25, 0.25, 0.08)])
    t = np.linspace(0, 1, len(pts))
    tt = np.linspace(0.08, 0.92, 8)
    path = np.array([np.interp(tt, t, pts[:, i]) for i in range(3)]).T
    for k, p in enumerate(path):
        out = np.array([p[0], 0, p[2] - 0.0])
        out = out / np.linalg.norm(out) + (0, 0.3, -0.5)
        rose(p, 0.16 if k % 2 else 0.14, out)
        if k % 2 == 0:
            leaf(p + (0.05, -0.08, -0.05), out + (0.4, -0.8, 0), 0.26, 0.14)


def base_flowers():
    y = PEDESTAL_TOP + 0.1
    for (x, z, s) in [(-1.45, -1.35, 0.2), (-1.05, -1.62, 0.16), (1.35, -1.45, 0.19),
                      (1.6, 1.2, 0.18), (-1.55, 1.3, 0.2), (-1.2, 1.6, 0.15)]:
        rose((x, y + s * 0.4, z), s, (rng.uniform(-0.3, 0.3), 1, rng.uniform(-0.3, 0.3)))
        for a in rng.uniform(0, 6.3, 2):
            d = np.array([math.cos(a), -0.15, math.sin(a)])
            leaf((x + d[0] * s * 0.6, y + 0.02, z + d[2] * s * 0.6), d, 0.3, 0.16)


def build():
    build_pedestal()
    robe()
    arms()
    feet()
    brooch()
    wreath = head()
    garland(wreath)
    base_flowers()
    flowers_a, flowers_b = flowers[0::2], flowers[1::2]
    lines_a, lines_b = flower_lines[0::2], flower_lines[1::2]
    parts = {"Marble": trimesh.util.concatenate(marble),
             "Pedestal": trimesh.util.concatenate(pedestal),
             "Letters": trimesh.util.concatenate(letters),
             "Veins": trimesh.util.concatenate(veins),
             "Flowers": trimesh.util.concatenate(flowers_a),
             "Flowers2": trimesh.util.concatenate(flowers_b),
             "Outline": trimesh.util.concatenate(outline),
             "OutlineFlowers": trimesh.util.concatenate(lines_a),
             "OutlineFlowers2": trimesh.util.concatenate(lines_b)}
    colours = {"Marble": MARBLE, "Pedestal": PEDESTAL, "Letters": LETTERS,
               "Veins": VEINS, "Flowers": MARBLE, "Flowers2": MARBLE,
               "Outline": BLACK, "OutlineFlowers": BLACK, "OutlineFlowers2": BLACK}
    # Built at about 9.4 studs, then scaled as a whole (Wylie: 14 studs tall).
    low = min(m.bounds[0][1] for m in parts.values())   # the keyline dips just under the base
    height = max(m.bounds[1][1] for m in parts.values()) - low
    scale = TOTAL_HEIGHT / height
    for m in parts.values():
        m.apply_translation((0, -low, 0))
        m.apply_scale(scale)
    extras = {"pedestalTop": round((PEDESTAL_TOP - low) * scale, 3), "scale": round(scale, 4),
              "note": "Static statue. Set each part's Color from the colour values here; "
                      "Material SmoothPlastic keeps the cartoon look.",
              "previewViews": {"top": {"azimuth": 150, "elevation": 18}}}
    info = kit.export(sys.argv[1], parts, colours, extras)
    print({k: v["triangles"] for k, v in info["parts"].items()}, info["triangles"], info["size"])


if __name__ == "__main__":
    build()
