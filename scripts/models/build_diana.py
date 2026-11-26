"""Builds the Diana statue for the conservatory: Diana, Roman goddess of wild
animals, made the same way as Flora (build_flora.py) and the same size.

Wylie's brief (2026-11-26): Diana holding a bow, with animals from the game
at her feet: a toad, a snake, a skunk and a chameleon. The snake can go
round her neck like a scarf (draped loosely, not choking).

Following the references: the bow is held out at her left side, a quiver
of arrows is on her back, a crescent moon sits in her hair (Diana's sign)
and her right hand holds an arrow at her side. The snake lies over both
shoulders with its head raised at her chest. The toad, skunk and chameleon
sit on the pedestal round her feet.

Usage (from the repo root):
  python3 scripts/models/build_diana.py models/statues/Diana.glb

Parts are as for Flora, with Animals / Animals2 and OutlineAnimals /
OutlineAnimals2 in place of the flower parts. The bow, arrows and quiver
are in Marble.
"""
import math

import numpy as np
import trimesh
from scipy.interpolate import CubicSpline

import build_flora as f
import creature_kit as kit

FLORA_SCALE = 1.4926     # from Flora.json, so all the statues are the same size
PT = f.PEDESTAL_TOP
HEAD_TILT = 5            # looking just up and out


def smooth(points, n=40):
    pts = np.asarray(points, float)
    t = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    cs = CubicSpline(t, pts)
    return cs(np.linspace(0, t[-1], n))


def on_ball(c, r, direction, lift=0.0):
    """Point on an ellipsoid (centre c, radii r) in a direction, lifted off it."""
    d = np.asarray(direction, float)
    d /= np.linalg.norm(d)
    r = np.asarray(r, float)
    p = d / math.sqrt(np.sum((d / r) ** 2))
    n = p / r ** 2
    return np.asarray(c) + p + n / np.linalg.norm(n) * lift


def detail(m, t=f.OUTLINE_SMALL):
    f.add(m, t, f.flowers, f.flower_lines)


def dot(p, r=0.03):
    f.flower_lines.append(kit.ellipsoid(p, (r, r, r), rings=4, segments=6))


def detail_line(points, r=f.LINE * 0.8):
    f.line(points, r, to=f.flower_lines)


# ------------------------------------------------------------- the animals
# Each is built facing -Z standing on y = 0, then turned and placed by `put`.

class Animal:
    def __init__(self):
        self.solid, self.lines = [], []

    def part(self, m, t=f.OUTLINE_SMALL):
        self.solid.append((m, t))

    def ball(self, c, r, t=f.OUTLINE_SMALL, rings=7, segments=12):
        self.part(kit.ellipsoid(c, r, rings=rings, segments=segments), t)

    def tube(self, pts, w, t=f.OUTLINE_SMALL, up=(1, 0, 0), sections=10):
        w = list(w) if hasattr(w, "__len__") else [w] * len(pts)
        self.part(kit.sweep(pts, w, w, sections=sections, up=up), t)

    def line(self, pts, r=f.LINE * 0.8):
        p = np.asarray(pts, float)
        up = (0, 1, 0) if abs((p[-1] - p[0])[1]) < 0.9 * np.linalg.norm(p[-1] - p[0]) else (1, 0, 0)
        self.lines.append(kit.sweep(p, [r] * len(p), [r] * len(p), sections=5, up=up))

    def dot(self, p, r=0.03):
        self.lines.append(kit.ellipsoid(p, (r, r, r), rings=4, segments=6))

    def put(self, position, yaw, size=1.0):
        """Scale by `size`, turn `yaw` degrees about up (positive turns the
        face towards +X) and stand it at `position`."""
        m = trimesh.transformations.rotation_matrix(math.radians(-yaw), (0, 1, 0)) @ np.diag([size, size, size, 1])
        m[:3, 3] = position
        for mesh, t in self.solid:
            mesh = mesh.copy()
            mesh.apply_transform(m)
            detail(mesh, t)
        for mesh in self.lines:
            mesh = mesh.copy()
            mesh.apply_transform(m)
            f.flower_lines.append(mesh)


def toad():
    a = Animal()
    body_c, body_r = (0, 0.26, 0.06), (0.4, 0.26, 0.36)
    a.ball(body_c, body_r)
    head_c, head_r = (0, 0.3, -0.2), (0.34, 0.2, 0.25)
    a.ball(head_c, head_r)
    for sx in (1, -1):
        a.ball((sx * 0.17, 0.48, -0.24), (0.1, 0.1, 0.1))                 # eye bumps
        a.dot((sx * 0.17, 0.5, -0.335), 0.035)                            # pupils
        a.ball((sx * 0.33, 0.14, 0.15), (0.15, 0.14, 0.26))               # folded back legs
        a.ball((sx * 0.36, 0.03, -0.08), (0.12, 0.04, 0.12), rings=4)     # back feet
        a.tube([(sx * 0.22, 0.22, -0.22), (sx * 0.27, 0.12, -0.33), (sx * 0.29, 0.04, -0.38)],
               0.055, sections=8)                                         # front legs
        a.ball((sx * 0.29, 0.025, -0.43), (0.08, 0.03, 0.08), rings=4)    # front feet
    # Wide smile across the front of the head.
    a.line([on_ball(head_c, head_r, (math.sin(u), -0.25 - 0.15 * math.cos(u), -math.cos(u)), 0.01)
            for u in np.linspace(-1.1, 1.1, 14)])
    # Warts on the back.
    for k in range(7):
        d = (f.rng.uniform(-0.8, 0.8), 1.0, f.rng.uniform(0.0, 0.9))
        a.ball(on_ball(body_c, body_r, d), (0.035, 0.03, 0.035), rings=4, segments=6)
    return a


def skunk():
    a = Animal()
    body_c, body_r = (0, 0.33, 0.05), (0.26, 0.33, 0.28)
    a.ball(body_c, body_r)
    head_c, head_r = (0, 0.74, -0.08), (0.2, 0.18, 0.2)
    a.ball(head_c, head_r)
    a.ball((0, 0.69, -0.29), (0.085, 0.075, 0.13))                        # snout
    a.dot((0, 0.71, -0.42), 0.04)                                         # nose
    for sx in (1, -1):
        a.ball((sx * 0.13, 0.9, -0.03), (0.065, 0.085, 0.04), rings=5, segments=8)   # ears
        a.dot((sx * 0.09, 0.79, -0.245), 0.03)                            # eyes
        a.ball((sx * 0.12, 0.07, -0.22), (0.08, 0.07, 0.1), rings=5, segments=8)     # front paws
        a.ball((sx * 0.2, 0.08, 0.1), (0.1, 0.08, 0.15), rings=5, segments=8)        # back feet
    # Big bushy tail curling up behind and over.
    tail = smooth([(0, 0.18, 0.3), (0, 0.45, 0.52), (0, 0.85, 0.56), (0, 1.15, 0.38), (0, 1.22, 0.12)], 16)
    w = list(np.interp(np.linspace(0, 1, 16), [0, 0.3, 0.7, 1], [0.1, 0.2, 0.2, 0.08]))
    a.tube(tail, w, sections=12)
    # The skunk's stripe: two lines from the head down the back and up the tail.
    for sx in (1, -1):
        back = [on_ball(head_c, head_r, (sx * 0.25, 1, 0.1 + 0.4 * t), 0.01) for t in np.linspace(0, 1, 4)]
        back += [on_ball(body_c, body_r, (sx * 0.28, 1 - 1.1 * t, 0.6 + 0.6 * t), 0.01) for t in np.linspace(0.15, 0.9, 8)]
        a.line(back)
        out = []
        for k in range(2, 15):
            tangent = tail[k + 1] - tail[k - 1]
            normal = np.cross(tangent, (1, 0, 0))
            normal /= np.linalg.norm(normal)
            if normal[2] < 0 and k < 8:
                normal = -normal
            out.append(tail[k] + normal * w[k] * 0.98 * math.cos(0.45) + np.array([sx * w[k] * math.sin(0.45), 0, 0]))
        a.line(out)
    return a


def chameleon():
    a = Animal()
    body_c, body_r = (0, 0.36, 0), (0.15, 0.22, 0.36)
    a.ball(body_c, body_r)
    head_c, head_r = (0, 0.42, -0.38), (0.13, 0.15, 0.17)
    a.ball(head_c, head_r)
    a.ball((0, 0.56, -0.31), (0.05, 0.1, 0.13), rings=5, segments=8)     # casque crest
    for sx in (1, -1):
        a.ball((sx * 0.12, 0.46, -0.42), (0.07, 0.07, 0.07), rings=6, segments=10)   # turret eyes
        a.dot((sx * 0.175, 0.47, -0.45), 0.025)
        for z, back in ((-0.18, False), (0.2, True)):                      # legs
            knee = (sx * 0.2, 0.3, z + (0.06 if back else -0.06))
            a.tube([(sx * 0.1, 0.33, z), knee, (sx * 0.2, 0.03, z + (0.1 if back else -0.1))], 0.04, sections=7)
            a.ball((sx * 0.2, 0.025, z + (0.1 if back else -0.1)), (0.05, 0.03, 0.06), rings=4, segments=7)
        # Mouth line along the side of the head.
        a.line([on_ball(head_c, head_r, (sx * 0.9, -0.3, -0.2 - 0.8 * t), 0.008) for t in np.linspace(0, 1, 6)])
    # Ridge down the back.
    a.line([on_ball(body_c, body_r, (0, 1, -0.9 + 1.6 * t), 0.01) for t in np.linspace(0, 1, 10)])
    # Tail curled into a spiral behind.
    centre = np.array([0, 0.24, 0.6])
    tail = [(0, 0.34, 0.33), (0, 0.33, 0.45)]
    for k in range(18):
        t = k / 17
        ang = math.pi * 0.5 + t * 3 * math.pi
        rad = 0.2 * (1 - 0.75 * t)
        tail.append(centre + (0, rad * math.sin(ang), rad * math.cos(ang) * -1 + 0.0))
    tail = smooth(tail, 24)
    w = list(np.linspace(0.075, 0.025, 24))
    a.tube(tail, w, sections=8)
    return a


# ------------------------------------------------------------- the snake

def snake():
    """Draped over both shoulders like a scarf, loose round the back of the
    neck, tail hanging at her right, head raised at her chest."""
    path = smooth([(0.42, PT + 3.5, -0.5), (0.46, PT + 3.85, -0.5), (0.5, PT + 4.22, -0.33),
                   (0.44, PT + 4.47, -0.04), (0.2, PT + 4.55, 0.3), (-0.15, PT + 4.55, 0.32),
                   (-0.44, PT + 4.47, 0.0), (-0.5, PT + 4.22, -0.34), (-0.42, PT + 3.95, -0.53),
                   (-0.24, PT + 3.86, -0.62), (-0.08, PT + 3.94, -0.72)], 60)
    w = list(np.interp(np.linspace(0, 1, 60), [0, 0.15, 0.5, 0.9, 1], [0.025, 0.09, 0.105, 0.09, 0.08]))
    detail(kit.sweep(path, w, w, sections=12, up=(0, 1, 0)), f.OUTLINE_SMALL)
    # Bands across the body.
    for k in range(6, 55, 6):
        tangent = path[k + 1] - path[k - 1]
        tangent /= np.linalg.norm(tangent)
        side = np.cross(tangent, (0, 1, 0))
        side /= np.linalg.norm(side)
        up = np.cross(side, tangent)
        ring = [path[k] + (side * math.cos(a) + up * math.sin(a)) * (w[k] + 0.008)
                for a in np.linspace(0, 2 * math.pi, 13)]
        detail_line(ring, f.LINE * 0.6)
    # Head, looking out and a little up.
    look = np.array([0.15, 0.35, -1.0])
    look /= np.linalg.norm(look)
    neck = path[-1]
    head_c = neck + look * 0.16
    head = kit.ellipsoid((0, 0, 0), (0.15, 0.1, 0.21), rings=8, segments=12)
    rot = trimesh.geometry.align_vectors([0, 0, -1], look)
    head.apply_transform(rot)
    head.apply_translation(head_c)
    detail(head)
    r3 = rot[:3, :3]
    for sx in (1, -1):
        eye = head_c + r3 @ np.array([sx * 0.095, 0.07, -0.05])
        detail(kit.ellipsoid(eye, (0.04, 0.04, 0.04), rings=5, segments=8), f.OUTLINE_SMALL * 0.7)
        dot(eye + r3 @ np.array([sx * 0.015, 0.01, -0.035]), 0.018)
    # Forked tongue.
    tip = head_c + r3 @ np.array([0, -0.025, -0.21])
    fork = tip + r3 @ np.array([0, 0, -0.1])
    detail_line([tip, fork], f.LINE * 0.6)
    for sx in (1, -1):
        detail_line([fork, fork + r3 @ np.array([sx * 0.035, -0.01, -0.05])], f.LINE * 0.55)


# ------------------------------------------------------------- bow and arrows

GRIP = np.array([-1.55, PT + 3.65, -0.62])   # her left hand (-X) holds the bow here
BOW_HALF = 1.25


def bow():
    t = np.linspace(-1, 1, 25)
    pts = [GRIP + (0.36 * s * s + 0.06 * max(0.0, abs(s) - 0.85) / 0.15, BOW_HALF * s, 0) for s in t]
    w = [0.075 - 0.04 * abs(s) for s in t]
    f.add(kit.sweep(pts, w, w, sections=8, up=(0, 0, 1)), f.OUTLINE_SMALL)
    # Grip wrap and the string.
    f.line([GRIP + (0, -0.12, 0), GRIP + (0, 0.12, 0)], 0.085)
    f.line([pts[0], pts[-1]], f.LINE * 0.7)


def arrow(tail, head_end):
    """An arrow from its feathered end to its point."""
    tail, head_end = np.asarray(tail, float), np.asarray(head_end, float)
    d = head_end - tail
    d /= np.linalg.norm(d)
    f.add(kit.sweep([tail, head_end], [0.03, 0.03], [0.03, 0.03], sections=6,
                    up=(0, 0, 1) if abs(d[2]) < 0.9 else (1, 0, 0)), f.OUTLINE_SMALL * 0.7)
    point = trimesh.creation.cone(radius=0.075, height=0.2, sections=8)
    point.apply_transform(trimesh.geometry.align_vectors([0, 0, 1], d))
    point.apply_translation(head_end)
    f.add(point, f.OUTLINE_SMALL * 0.8)
    side = np.cross(d, (0, 0, 1)) if abs(d[2]) < 0.9 else np.cross(d, (1, 0, 0))
    side /= np.linalg.norm(side)
    other = np.cross(d, side)
    for v in (side, -side, other, -other):   # feathers
        fl = [tail + d * 0.02, tail + d * 0.24 + v * 0.01, tail + d * 0.2 + v * 0.1, tail + d * 0.0 + v * 0.09]
        f.add(trimesh.convex.convex_hull(np.vstack([np.array(fl) + other * 0.0, np.array(fl) + np.cross(d, v) * 0.012])),
              f.OUTLINE_SMALL * 0.6)


def quiver():
    bottom, top = np.array([0.42, PT + 3.25, 0.55]), np.array([-0.22, PT + 4.55, 0.62])
    pts = [bottom + (top - bottom) * t for t in np.linspace(0, 1, 6)]
    w = [0.15, 0.17, 0.18, 0.18, 0.18, 0.19]
    f.add(kit.sweep(pts, w, w, sections=12, up=(0, 0, 1)))
    d = (top - bottom) / np.linalg.norm(top - bottom)
    for off in ((0.06, 0, -0.05), (-0.07, 0.02, 0.0), (0.0, -0.02, 0.07)):
        start = top + np.array(off) - d * 0.3
        tail = start + d * 0.55
        arrow(tail, start - d * 0.01)   # only the feathered ends show above the rim


def arms():
    # Left arm (-X) reaches out to the side holding the bow.
    s = f.SHOULDER * (-1, 1, 1)
    e = np.array([-1.02, PT + 3.78, -0.36])
    h = GRIP + (0.06, 0, 0)
    f.add(kit.ellipsoid(s + (0, 0.02, 0), (0.27, 0.24, 0.26)))
    pts = [s + (e - s) * t for t in np.linspace(0.05, 1.0, 9)]
    w = list(np.linspace(0.2, 0.31, 9))
    f.add(kit.sweep(pts, w, w, sections=12, up=(0, 0, 1)))
    pts = [e + (h - e) * t for t in np.linspace(-0.1, 0.95, 8)]
    w = list(np.linspace(0.15, 0.13, 8))
    f.add(kit.sweep(pts, w, w, sections=10, up=(0, 1, 0)))
    f.add(kit.ellipsoid(h, (0.13, 0.15, 0.14)))   # fist round the grip
    bow()
    # Right arm (+X) down at her side, holding an arrow pointing down.
    s = f.SHOULDER
    e = np.array([0.92, PT + 3.05, 0.1])
    h = np.array([1.1, PT + 2.55, -0.3])
    f.add(kit.ellipsoid(s + (0, 0.02, 0), (0.27, 0.24, 0.26)))
    pts = [s + (e - s) * t for t in np.linspace(0.05, 1.0, 9)]
    w = list(np.linspace(0.2, 0.33, 9))
    f.add(kit.sweep(pts, w, w, sections=12, up=(0, 0, 1)))
    pts = [e + (h - e) * t for t in np.linspace(-0.1, 1.0, 8)]
    w = list(np.linspace(0.16, 0.13, 8))
    f.add(kit.sweep(pts, w, w, sections=10, up=(0, 1, 0)))
    f.add(kit.ellipsoid(h + (0.02, 0, -0.03), (0.15, 0.14, 0.17)))
    arrow(h + (0.03, 0.5, 0.12), h + (0.05, -0.62, -0.25))
    quiver()
    snake()


def crescent():
    """Diana's crescent moon, horns up, at the front of her hair."""
    from shapely.geometry import Point
    shape = Point(0, 0).buffer(1.0, 32).difference(Point(0, 0.45).buffer(0.82, 32))
    pts = list(shape.exterior.coords)[:-1]
    m = kit.flat_shape(pts, 0.25)
    m.apply_scale(0.22)
    tilt = trimesh.transformations.rotation_matrix(math.radians(HEAD_TILT), (1, 0, 0), f.PIVOT)
    m.apply_translation(f.on_head(0, 62, 0.12) + (0, 0.12, 0))
    m.apply_transform(tilt)
    f.add(m, f.OUTLINE_SMALL)


def brooch():
    crescent()   # the brooch is hidden by the snake; the moon goes in her hair instead


def base_animals():
    toad().put((-1.3, PT, -1.25), -25, 1.1)
    skunk().put((1.42, PT, -0.95), 20, 1.1)
    chameleon().put((0.42, PT, -1.62), 90, 1.15)   # side on, so its curled tail shows from the front


def build():
    f.NAME = "DIANA"
    f.DETAIL = "Animals"
    f.HEAD_TILT = HEAD_TILT
    f.WREATH = False
    f.FIXED_SCALE = FLORA_SCALE
    f.arms = arms
    f.brooch = brooch
    f.garland = lambda wreath: None
    f.base_flowers = base_animals
    f.build()


if __name__ == "__main__":
    build()
