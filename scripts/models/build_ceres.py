"""Builds the Ceres statue for the conservatory: Ceres, Roman goddess of
fertile plants and grains, made the same way as Flora (build_flora.py) and
the same size.

Wylie's brief (2026-11-26): Ceres holding a bundle of plants and grains,
with a flower wreath crown. Following the reference, she holds a sheaf of
wheat up against her right shoulder and a second sheaf low at her left
hip. Her crown is roses and daisies; daisies and a stray ear of wheat lie
on the pedestal top.

Usage (from the repo root):
  python3 scripts/models/build_ceres.py models/statues/Ceres.glb

Parts are as for Flora, with Grain / Grain2 and OutlineGrain /
OutlineGrain2 in place of the flower parts.
"""
import math

import numpy as np
import trimesh

import build_flora as f
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


def base_plants():
    y = PT + 0.05
    for (x, z, s) in [(-1.45, -1.35, 0.28), (-0.95, -1.62, 0.22), (1.55, 1.25, 0.26), (-1.55, 1.3, 0.27)]:
        daisy((x, y + 0.04, z), s, (f.rng.uniform(-0.25, 0.25), 1, f.rng.uniform(-0.25, 0.25)))
        for a in f.rng.uniform(0, 6.3, 2):
            d = np.array([math.cos(a), -0.15, math.sin(a)])
            f.leaf((x + d[0] * s * 0.6, y + 0.02, z + d[2] * s * 0.6), d, 0.28, 0.14)
    # Two stray ears of wheat lying at the front right.
    for (x, z, a) in [(1.0, -1.55, 2.6), (1.35, -1.25, 2.2)]:
        d = np.array([math.cos(a), 0.05, math.sin(a)])
        start = np.array([x, y + 0.04, z])
        stalk([start - d * 0.4, start])
        ear(start, d, grains=6)


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
