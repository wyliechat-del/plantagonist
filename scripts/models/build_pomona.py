"""Builds the Pomona statue for the conservatory: Pomona, Roman goddess of
fruit, made the same way as Flora (build_flora.py) and the same size.

Wylie's brief (2026-11-26): a similar design to Flora, keeping her young
girl look in Roman robes, but holding a bowl of fruit (oranges, apples,
grapes and so on). The pose follows the bronze Pomona reference: a wide
shallow bowl held in front at the waist with both hands.

Usage (from the repo root):
  python3 scripts/models/build_pomona.py models/statues/Pomona.glb

Everything Flora has (pedestal, robe, face, curls, keyline, veins) comes from
build_flora.py; this script swaps in the arms holding the bowl, the fruit,
a wreath of grapes and apples, an apple brooch and fruit round her feet.
It uses Flora's scale, so the two pedestals match.

Parts are as for Flora, with Fruit / Fruit2 and OutlineFruit /
OutlineFruit2 in place of the flower parts.
"""
import math

import numpy as np
import trimesh

import build_flora as f
import creature_kit as kit

FLORA_SCALE = 1.4926     # from Flora.json, so both statues are the same size
BOWL_C = np.array([0.0, f.PEDESTAL_TOP + 2.82, -0.78])   # bottom of the bowl's foot
BOWL_R = 1.05            # rim radius, build units
# Bowl side profile (radius, height): out along the foot, up the outside to
# the rim, then back down the inside.
BOWL_PROFILE = [(0, 0), (0.3, 0), (0.32, 0.08), (0.45, 0.12), (0.85, 0.26), (1.0, 0.4),
                (1.05, 0.45), (1.0, 0.47), (0.82, 0.34), (0.4, 0.24), (0, 0.22)]
RIM_Y = BOWL_C[1] + 0.47
FRUIT_SCALE = 1.3        # all fruit, so it reads from a distance


def fruit_add(m, t=f.OUTLINE_SMALL):
    f.add(m, t, f.flowers, f.flower_lines)


def stem(top, facing, length=0.09):
    d = np.asarray(facing, float)
    d /= np.linalg.norm(d)
    bend = np.cross(d, (0, 0, 1)) if abs(d[2]) < 0.9 else np.cross(d, (1, 0, 0))
    pts = [top + d * length * t + bend * 0.03 * t * t for t in np.linspace(0, 1, 5)]
    w = [0.03, 0.028, 0.025, 0.022, 0.02]
    fruit_add(kit.sweep(pts, w, w, sections=6, up=bend), f.OUTLINE_SMALL * 0.7)


def lathe_fruit(profile, centre, r, facing, centre_h):
    """A round fruit spun from a (radius, height) profile, sized r, with its
    top pointing along `facing` and its middle at `centre`. Returns the top."""
    m = kit.lathe([(a * r, (b - centre_h) * r) for a, b in profile], sections=14)
    top_local = np.array([0, (profile[-1][1] - centre_h) * r, 0])
    fruit_add(f.place(m, centre, facing))
    rot = trimesh.geometry.align_vectors([0, 1, 0], np.asarray(facing, float) / np.linalg.norm(facing))
    return np.asarray(centre) + rot[:3, :3] @ top_local


APPLE = [(0, 0.06), (0.35, 0.0), (0.75, 0.12), (0.98, 0.42), (1.0, 0.62), (0.88, 0.88),
         (0.55, 1.02), (0.22, 0.98), (0, 0.86)]
PEAR = [(0, 0), (0.55, 0.03), (0.92, 0.3), (0.98, 0.55), (0.8, 0.85), (0.55, 1.08),
        (0.45, 1.35), (0.33, 1.55), (0, 1.62)]


def apple(centre, r, facing=(0, 1, 0), leafy=True):
    r *= FRUIT_SCALE
    top = lathe_fruit(APPLE, centre, r, facing, 0.5)
    stem(top, facing)
    if leafy:
        d = np.asarray(facing, float) + (0.8, 0.1, -0.5)
        f.leaf(top, d, r * 1.2, r * 0.5)


def pear(centre, r, facing=(0, 1, 0)):
    r *= FRUIT_SCALE
    top = lathe_fruit(PEAR, centre, r, facing, 0.6)
    stem(top, facing, 0.1)


def orange(centre, r, facing=(0, 1, 0)):
    r *= FRUIT_SCALE
    """An orange: a ball with a little nub on top and a few pore dots, so
    it reads differently from an apple."""
    r *= FRUIT_SCALE
    ball = kit.ellipsoid((0, 0, 0), (r, r * 0.94, r), rings=8, segments=14)
    fruit_add(f.place(ball, centre, facing))
    nub = kit.ellipsoid((0, r * 0.95, 0), (r * 0.16, r * 0.08, r * 0.16), rings=4, segments=8)
    fruit_add(f.place(nub, centre, facing), f.OUTLINE_SMALL * 0.6)
    for k in range(7):
        a, v = f.rng.uniform(0, 6.3), f.rng.uniform(0.0, 1.0)
        p = np.array([math.cos(a) * math.cos(v), math.sin(v) * 0.94, math.sin(a) * math.cos(v)]) * r * 1.01
        dot = kit.ellipsoid(p, (0.018, 0.018, 0.018), rings=3, segments=5)
        f.flower_lines.append(f.place(dot, centre, facing))


def grapes(top, r, hang=(0, -1, 0), rows=(4, 4, 3, 3, 2, 1)):
    """A bunch of grapes hanging from `top` along `hang`: rows of small
    balls getting narrower towards the tip, with a curly stalk on top."""
    r *= FRUIT_SCALE
    h = np.asarray(hang, float)
    h /= np.linalg.norm(h)
    side = np.cross(h, (0, 0, 1)) if abs(h[2]) < 0.9 else np.cross(h, (1, 0, 0))
    side /= np.linalg.norm(side)
    other = np.cross(h, side)
    n = len(rows)
    for i, count in enumerate(rows):
        ring = r * 1.25 * (1 - 0.75 * i / n) * (1 if count > 1 else 0)
        for k in range(count):
            a = 2 * math.pi * k / count + i * 0.7
            p = np.asarray(top) + h * r * 1.5 * (i + 0.7) + (side * math.cos(a) + other * math.sin(a)) * ring
            fruit_add(kit.ellipsoid(p, (r, r, r), rings=5, segments=8), f.OUTLINE_SMALL * 0.7)
    stalk = [np.asarray(top) - h * r * 1.6 * t + side * 0.6 * r * math.sin(t * 4) for t in np.linspace(0, 1, 6)]
    w = [0.022] * 6
    fruit_add(kit.sweep(stalk, w, w, sections=5, up=other), f.OUTLINE_SMALL * 0.6)


# ------------------------------------------------------------- bowl and arms

def bowl():
    m = kit.lathe([(a, b) for a, b in BOWL_PROFILE], sections=40)
    m.apply_translation(BOWL_C)
    f.add(m)
    # A rim line round the inside edge, for a cartoon lip.
    ring = [BOWL_C + (0.99 * math.cos(t), 0.475, 0.99 * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 49)]
    f.line(ring, f.LINE * 0.8)


def bowl_fruit():
    """The heap of fruit in the bowl, with bunches of grapes over the rim."""
    c = np.array([BOWL_C[0], RIM_Y, BOWL_C[2]])
    ring = [apple, orange, pear, orange, apple, orange, apple]
    for k, make in enumerate(ring):
        a = 2 * math.pi * k / len(ring) + 0.3
        off = np.array([math.cos(a) * 0.62, 0.02, math.sin(a) * 0.6])
        tilt = off * 0.8 + (0, 1, 0)
        if make is pear:
            pear(c + off + (0, 0.03, 0), 0.19, tilt)
        elif make is apple:
            apple(c + off, 0.2, tilt, leafy=k == 0)
        else:
            orange(c + off, 0.2, tilt)
    orange(c + (0.2, 0.24, -0.1), 0.21, (0.2, 1, -0.3))
    apple(c + (-0.22, 0.24, 0.08), 0.21, (-0.2, 1, 0.1))
    grapes(c + (0.0, 0.42, 0.2), 0.065, (0.1, -0.35, -1.0), rows=(3, 3, 2, 1))
    # Bunches spilling over the front and the side of the rim.
    grapes(c + (-0.3, 0.12, -0.85), 0.07, (-0.15, -1, -0.45))
    grapes(c + (0.88, 0.1, -0.35), 0.065, (0.5, -1, -0.2))
    for a in (0.8, 2.6, 4.0, 5.4):
        d = np.array([math.cos(a), 0.15, math.sin(a)])
        f.leaf(c + d * 0.8 + (0, 0.05, 0), d, 0.32, 0.17)


def arms():
    rim_side = BOWL_C + (BOWL_R * 0.97, 0.42, 0.0)
    for sx in (1, -1):
        m = np.diag([sx, 1, 1])
        s = f.SHOULDER @ m
        e = np.array([0.9, f.PEDESTAL_TOP + 3.22, 0.12]) @ m
        h = rim_side @ m
        f.add(kit.ellipsoid(s + (0, 0.02, 0), (0.27, 0.24, 0.26)))
        pts = [s + (e - s) * t for t in np.linspace(0.05, 1.0, 9)]
        w = list(np.linspace(0.2, 0.33, 9))
        f.add(kit.sweep(pts, w, w, sections=12, up=(0, 0, 1)))
        pts = [e + (h - e) * t for t in np.linspace(-0.1, 0.95, 8)]
        w = list(np.linspace(0.16, 0.13, 8))
        f.add(kit.sweep(pts, w, w, sections=10, up=(0, 1, 0)))
        # Hand curled over the rim, fingers inside, thumb on top.
        f.add(kit.ellipsoid(h + (0.03 * sx, 0.06, 0), (0.13, 0.12, 0.17)))
    bowl()
    bowl_fruit()


def brooch():
    p = f.robe_point(-math.pi / 2, 3.85, 0.06)
    apple(p, 0.1, (0, 0.6, -1), leafy=False)


def wreath_item(p, k, facing):
    """Pomona's wreath: small bunches of grapes and little apples."""
    if k % 2:
        apple(p, 0.11, facing, leafy=False)
    else:
        down = np.asarray(facing, float) * 0.3 + (0, -1, 0)
        grapes(p + (0, 0.05, 0), 0.045, down, rows=(3, 3, 2, 1))


def base_fruit():
    y = f.PEDESTAL_TOP
    apple((-1.45, y + 0.2, -1.35), 0.22, (0.2, 1, -0.2))
    orange((-1.0, y + 0.2, -1.62), 0.2, (0, 1, 0))
    pear((1.4, y + 0.17, -1.4), 0.21, (1, 0.35, -0.2))        # lying on its side
    grapes((1.55, y + 0.6, 1.1), 0.07, (0.1, -1, 0.05), rows=(4, 3, 3, 2, 1))
    orange((-1.5, y + 0.2, 1.3), 0.2, (0.2, 1, 0.1))
    apple((-1.05, y + 0.19, 1.62), 0.19, (-0.3, 1, 0.2))
    for x, z in [(-1.3, -1.6), (1.6, -1.1), (-1.7, 1.0)]:
        a = f.rng.uniform(0, 6.3)
        d = np.array([math.cos(a), -0.15, math.sin(a)])
        f.leaf((x, y + 0.03, z), d, 0.3, 0.16)


def build():
    f.NAME = "POMONA"
    f.DETAIL = "Fruit"
    f.HEAD_TILT = -4          # looking just down towards her bowl
    f.FIXED_SCALE = FLORA_SCALE
    f.arms = arms
    f.brooch = brooch
    f.wreath_item = wreath_item
    f.garland = lambda wreath: None
    f.base_flowers = base_fruit
    f.build()


if __name__ == "__main__":
    build()
