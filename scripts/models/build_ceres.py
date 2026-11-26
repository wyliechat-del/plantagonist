"""Builds the Ceres statue for the conservatory: Ceres, Roman goddess of
fertile plants and grains, made the same way as Flora (build_flora.py) and
the same size.

Wylie's brief (2026-11-26): Ceres holding a bundle of plants and grains,
with a flower wreath crown. Following the reference, she holds a sheaf of
wheat up against her right shoulder and a second sheaf low at her left
hip. Her crown is roses and daisies. Round 2 (Wylie): the fallen wheat is
gone; big leaves lie at the pedestal's corners with toad-sized bees and
ants on them, and two daisies between.

Usage (from the repo root):
  python3 scripts/models/build_ceres.py models/statues/Ceres.glb

Parts are as for Flora, with Grain / Grain2 and OutlineGrain /
OutlineGrain2 in place of the flower parts.
"""
import math

import numpy as np
import trimesh

import build_flora as f
from build_diana import Animal
import creature_kit as kit

FLORA_SCALE = 1.4926     # from Flora.json, so all the statues are the same size
PT = f.PEDESTAL_TOP


def detail(m, t=f.OUTLINE_SMALL):
    f.add(m, t, f.flowers, f.flower_lines)


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def across(d):
    s = np.cross(d, (0, 0, 1)) if abs(d[2]) < 0.9 else np.cross(d, (1, 0, 0))
    return unit(s)


# ------------------------------------------------------------- wheat

def ear(base, direction, grains=6, size=1.0):
    """An ear of wheat: plump grains in two rows up the stalk tip, with a
    few whiskers (awns) at the top."""
    e = unit(direction)
    side = across(e)
    for j in range(grains):
        for sx in (1, -1):
            p = base + e * size * (0.06 + 0.075 * j + (0.035 if sx < 0 else 0)) + side * sx * 0.035 * size
            g = kit.ellipsoid((0, 0, 0), (0.04 * size, 0.07 * size, 0.035 * size), rings=4, segments=6)
            detail(f.place(g, p, e + side * sx * 0.35), f.OUTLINE_SMALL * 0.6)
    tip = base + e * size * (0.06 + 0.075 * grains)
    for a in (-0.35, 0.0, 0.35):
        f.line([tip - e * 0.05 * size, tip + (e + side * a) * 0.2 * size], f.LINE * 0.45, to=f.flower_lines)


def stalk(points, r=0.025):
    pts = np.asarray(points, float)
    d = pts[-1] - pts[0]
    detail(kit.sweep(pts, [r] * len(pts), [r] * len(pts), sections=5, up=across(unit(d))), f.OUTLINE_SMALL * 0.5)


def sheaf(tie, axis, below, above, count, spread, out):
    """A bundle of wheat tied at `tie`: stalks run along `axis`, fanning out
    to ears at the top and a little at the bottom. `out` is the side the
    fan opens towards (sideways to the viewer)."""
    axis, out = unit(axis), unit(out)
    deep = unit(np.cross(axis, out))
    for i in range(count):
        a = -1 + 2 * i / max(count - 1, 1)
        wob = f.rng.uniform(-0.25, 0.25)
        fan = out * a * spread + deep * wob * spread * 0.6
        top = tie + axis * above * (1 - 0.12 * abs(a)) + fan
        bottom = tie - axis * below - fan * 0.35
        mid = tie + fan * 0.05
        stalk([bottom, mid, tie + axis * above * 0.45 + fan * 0.55, top])
        ear(top, top - (tie + axis * above * 0.45 + fan * 0.55), grains=6, size=1.0 + f.rng.uniform(-0.1, 0.1))
    # A few long leaves hanging out of the bundle.
    for a in (-0.8, 0.3, 0.9):
        d = unit(axis * 0.6 + out * a + deep * 0.3)
        f.leaf(tie + axis * above * 0.25, d, 0.55, 0.09)
    # The tie: a band round the bundle.
    ring = [tie + (out * math.cos(t) + deep * math.sin(t)) * 0.13 for t in np.linspace(0, 2 * math.pi, 17)]
    detail(kit.sweep(ring, [0.045] * 17, [0.045] * 17, sections=6, up=axis), f.OUTLINE_SMALL * 0.7)


# ------------------------------------------------------------- flowers

def daisy(centre, size, facing):
    """A daisy: a round middle and a ring of petals, facing out."""
    detail(f.place(kit.ellipsoid((0, 0, 0), (size * 0.38, size * 0.22, size * 0.38), rings=5, segments=8),
                   centre, facing))
    for k in range(9):
        a = 2 * math.pi * k / 9
        petal = kit.ellipsoid((size * 0.75, -size * 0.05, 0), (size * 0.42, size * 0.07, size * 0.15),
                              rings=3, segments=6)
        petal.apply_transform(trimesh.transformations.rotation_matrix(a, (0, 1, 0)))
        detail(f.place(petal, centre, facing), f.OUTLINE_SMALL * 0.6)


def wreath_item(p, k, facing):
    """Ceres' crown: roses and daisies in turn."""
    if k % 2:
        f.rose(p, 0.16, facing)
    else:
        daisy(p, 0.24, facing)


def brooch():
    p = f.robe_point(-math.pi / 2, 3.85, 0.04)
    daisy(p, 0.14, (0, 0.25, -1))


# ------------------------------------------------------------- arms

def arm(s, e, h, flare=0.33):
    f.add(kit.ellipsoid(s + (0, 0.02, 0), (0.27, 0.24, 0.26)))
    pts = [s + (e - s) * t for t in np.linspace(0.05, 1.0, 9)]
    w = list(np.linspace(0.2, flare, 9))
    f.add(kit.sweep(pts, w, w, sections=12, up=(0, 0, 1)))
    pts = [e + (h - e) * t for t in np.linspace(-0.1, 1.0, 8)]
    w = list(np.linspace(0.16, 0.13, 8))
    f.add(kit.sweep(pts, w, w, sections=10, up=(0, 1, 0)))
    f.add(kit.ellipsoid(h, (0.15, 0.14, 0.17)))


def arms():
    # Right arm (+X): the sheaf is held up against her shoulder.
    hand = np.array([0.52, PT + 3.45, -0.66])
    arm(f.SHOULDER, np.array([0.98, PT + 3.25, -0.12]), hand)
    sheaf(hand + (0.2, 0.05, -0.08), (0.32, 1, 0.05), below=0.85, above=1.05, count=9,
          spread=0.42, out=(1, -0.25, 0))
    # Left arm (-X): the second sheaf held low at her hip, ears up.
    s = f.SHOULDER * (-1, 1, 1)
    hand = np.array([-1.12, PT + 2.6, -0.42])
    arm(s, np.array([-0.92, PT + 3.05, 0.1]), hand)
    sheaf(hand + (-0.06, 0.08, -0.04), (-0.18, 1, -0.05), below=0.9, above=0.95, count=8,
          spread=0.38, out=(-1, 0.15, 0))


def big_leaf(base, direction, length=1.75, width=0.65):
    """A broad leaf lying on the pedestal, edges curling up a little, with
    a midrib and side veins drawn on. Returns the middle of its top face."""
    d = unit((direction[0], 0, direction[2]))
    side = unit(np.cross(d, (0, 1, 0)))
    up = np.array([0.0, 1.0, 0.0])
    t = np.linspace(0, 1, 9)
    spine = [np.asarray(base) + d * length * s + up * (0.07 + 0.06 * math.sin(math.pi * s)) for s in t]
    widths = width * 1.6 * np.array([0.15, 0.6, 0.85, 0.97, 1.0, 0.93, 0.75, 0.45, 0.03])
    m = kit.blade(spine, [side] * 9, [up] * 9, widths, fold=0.25, thickness=0.04)
    detail(m, f.OUTLINE_SMALL)
    lift = up * 0.03
    f.line([p + lift for p in spine[:-1]], f.LINE * 0.7, to=f.flower_lines)
    for k in range(1, 7):
        for sx in (1, -1):
            a = spine[k] + lift
            b = spine[min(k + 1, 8)] + side * sx * widths[k] * 0.4 + up * (0.02 + 0.25 * widths[k] * 0.4)
            f.line([a, b], f.LINE * 0.5, to=f.flower_lines)
    return spine[4] + up * 0.03


def bee():
    """A round cartoon bee standing on six legs, wings up, facing -Z."""
    a = Animal()
    ab_c, ab_r = np.array([0, 0.34, 0.22]), np.array([0.26, 0.25, 0.34])
    a.ball(ab_c, ab_r)
    for zz in (-0.12, 0.04, 0.19):                         # stripes
        k = math.sqrt(1 - (zz / ab_r[2]) ** 2) * 1.03
        a.line([ab_c + (ab_r[0] * k * math.cos(t), ab_r[1] * k * math.sin(t), zz)
                for t in np.linspace(0, 2 * math.pi, 17)], f.LINE * 0.9, up=(0, 0, 1))
    sting = trimesh.creation.cone(radius=0.05, height=0.13, sections=8)
    sting.apply_transform(trimesh.geometry.align_vectors([0, 0, 1], [0, -0.2, 1]))
    sting.apply_translation(ab_c + (0, -0.04, 0.32))
    a.part(sting)
    a.ball((0, 0.36, -0.12), (0.21, 0.2, 0.2))             # fuzzy middle
    head_c, head_r = np.array([0, 0.4, -0.37]), np.array([0.18, 0.17, 0.16])
    a.ball(head_c, head_r)
    for sx in (1, -1):
        a.dot(head_c + (sx * 0.08, 0.04, -0.15), 0.035)     # eyes
        tip = head_c + (sx * 0.15, 0.32, -0.12)
        a.line([head_c + (sx * 0.06, 0.13, -0.06), head_c + (sx * 0.1, 0.26, -0.06), tip])
        a.ball(tip, (0.035, 0.035, 0.035), rings=4, segments=6)
        wing = kit.flat_shape([(0.13 * math.cos(t), 0.3 * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 20, endpoint=False)], 0.025)
        wing.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2, (1, 0, 0)))
        wing.apply_transform(trimesh.transformations.rotation_matrix(math.radians(sx * 28), (0, 0, 1)))
        wing.apply_translation((sx * 0.2, 0.6, 0.12))
        a.part(wing)
        for z in (-0.2, -0.08, 0.05):                       # legs
            a.tube([(sx * 0.12, 0.25, z), (sx * 0.24, 0.16, z - 0.03), (sx * 0.27, 0.02, z - 0.06)], 0.03, sections=6)
    a.line([head_c + (math.sin(u) * 0.12, -0.05 - 0.03 * math.cos(u), -0.15) for u in np.linspace(-1.0, 1.0, 7)])
    return a


def ant():
    """A cartoon ant: big head, small middle, round back end, elbowed
    feelers and six bent legs, facing -Z."""
    a = Animal()
    head_c = np.array([0, 0.36, -0.42])
    a.ball(head_c, (0.17, 0.15, 0.16))
    a.ball((0, 0.3, -0.16), (0.1, 0.1, 0.17))              # middle
    a.ball((0, 0.28, 0.03), (0.06, 0.06, 0.06), rings=5, segments=8)   # waist
    a.ball((0, 0.33, 0.27), (0.21, 0.2, 0.27))             # back end
    for sx in (1, -1):
        a.dot(head_c + (sx * 0.09, 0.05, -0.14), 0.035)
        elbow = head_c + (sx * 0.1, 0.3, -0.02)
        a.line([head_c + (sx * 0.06, 0.12, -0.08), elbow, elbow + (sx * 0.08, 0.05, -0.22)])
        a.ball(head_c + (sx * 0.05, -0.1, -0.15), (0.035, 0.03, 0.06), rings=4, segments=6)   # jaws
        for z, lean in ((-0.25, -0.12), (-0.16, 0.0), (-0.07, 0.14)):
            a.tube([(sx * 0.07, 0.27, z), (sx * 0.21, 0.33, z + lean * 0.5), (sx * 0.28, 0.02, z + lean)], 0.035, sections=6)
    a.line([head_c + (math.sin(u) * 0.1, -0.06 - 0.03 * math.cos(u), -0.15) for u in np.linspace(-1.0, 1.0, 7)])
    return a


TOAD_SIZE = 1.1          # Diana's toad is put at this size; bees and ants match it


def base_plants():
    """Big leaves at the four corners with a bee or an ant on each (Wylie,
    round 2: the fallen wheat is gone), and two daisies between them."""
    y = PT
    for (cx, cz, make, yaw) in [(-1.0, -1.0, bee, -25), (1.0, -1.0, ant, 25),
                                (1.0, 1.0, bee, 100), (-1.0, 1.0, ant, -100)]:
        d = np.array([cx, 0, cz])
        top = big_leaf(np.array([cx * 0.55, y, cz * 0.55]), d)
        make().put(top, yaw, TOAD_SIZE)
    for (x, z, s) in [(0.62, -1.75, 0.2), (0.0, 1.75, 0.22)]:
        daisy((x, y + 0.09, z), s, (0, 1, 0))


def build():
    f.NAME = "CERES"
    f.DETAIL = "Grain"
    f.FIXED_SCALE = FLORA_SCALE
    f.HEAD_TILT = 6
    f.arms = arms
    f.brooch = brooch
    f.wreath_item = wreath_item
    f.garland = lambda wreath: None
    f.base_flowers = base_plants
    f.build()


if __name__ == "__main__":
    build()
