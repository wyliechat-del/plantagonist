"""Builds the Purple Dragonfruit (the Venom family's fruit) from Wylie's
drawing: a magenta egg covered in pointed scales that fade from magenta at
the base to green at the tip, with a black keyline.

Usage (from the repo root):
  python3 scripts/models/build_dragonfruit.py models/creatures/DragonfruitVenom.glb

Measured from the drawing: the egg is 730 x 1050 px, a little fuller at the
bottom. Scales are triangles about a quarter of the egg's height, pointing
up, with their tips lifted off the skin; the top ones stick up past the top.
The model is HEIGHT studs tall (egg only) and sits on the origin.

Roblox parts are one colour each, so the scale's fade is done in three
bands: the base band is the skin colour (part of Skin), then a brownish
middle band (ScaleMid), then a green tip (ScaleTip).

Parts:
  Skin      magenta egg and the base of every scale
  ScaleMid  middle band of the scales
  ScaleTip  green tips
  Outline   black keyline round the egg and along each scale's two sides
"""
import math
import sys

import numpy as np

import creature_kit as kit

HEIGHT = 2.0                 # studs, egg only (the old fruit ball was 1.6 across)
WIDTH = HEIGHT * 730 / 1050

SKIN = (204, 40, 128, 255)
MID = (165, 105, 95, 255)
GREEN = (110, 175, 40, 255)
BLACK = (0, 0, 0, 255)

# Scale rows: (height up the egg 0..1, how many round it, turn offset in degrees)
ROWS = [(0.17, 5, 0), (0.36, 5, 36), (0.6, 5, 8), (0.82, 4, 50)]
SCALE_LEN = 0.28             # times HEIGHT
SCALE_WIDTH = 0.25           # times HEIGHT
SCALE_LIFT = 0.06            # how far the tip stands off the skin, times HEIGHT
SCALE_THICK = 0.012          # times HEIGHT
BANDS = (0.35, 0.62)         # where skin colour ends and green begins, along the scale
KEYLINE = 0.009              # times HEIGHT


def egg_radius(t):
    """Egg radius at height t (0 bottom .. 1 top), fuller at the bottom."""
    base = math.sqrt(max(0.0, 1 - (2 * t - 1) ** 2))
    return WIDTH / 2 * base * (1 + 0.08 * (0.5 - t))


def egg():
    profile = [(egg_radius(i / 24), HEIGHT * i / 24) for i in range(25)]
    profile[0] = (0.0, 0.0)
    profile[-1] = (0.0, HEIGHT)
    return kit.lathe(profile, sections=28)


def surface(t, angle):
    """Point on the egg, the outward normal there and the 'up the egg' direction."""
    a = math.radians(angle)
    r = egg_radius(t)
    p = np.array([r * math.sin(a), HEIGHT * t, -r * math.cos(a)])
    dt = 1e-3
    dr = (egg_radius(min(1, t + dt)) - egg_radius(max(0, t - dt))) / (2 * dt)
    up = np.array([dr * math.sin(a), HEIGHT, -dr * math.cos(a)])
    up /= np.linalg.norm(up)
    out = np.array([math.sin(a), 0.0, -math.cos(a)])
    out = out - up * out.dot(up)
    out /= np.linalg.norm(out)
    return p, out, up


def slab(points, thickness):
    """Thin flat plate from 3 or 4 corner points (all in one plane)."""
    pts = np.asarray(points, float)
    n = np.cross(pts[1] - pts[0], pts[-1] - pts[0])
    n /= np.linalg.norm(n)
    h = n * thickness / 2
    verts = np.vstack([pts + h, pts - h])
    k = len(pts)
    faces = [[0, i, i + 1] for i in range(1, k - 1)]
    faces += [[k, k + i + 1, k + i] for i in range(1, k - 1)]
    for i in range(k):
        j = (i + 1) % k
        faces += [[i, i + k, j + k], [i, j + k, j]]
    m = kit.trimesh.Trimesh(verts, np.array(faces), process=False)
    if m.volume < 0:
        m.invert()
    return m


def scale(t, angle):
    """One scale: three colour bands and its two black side lines."""
    p, out, up = surface(t, angle)
    side = np.cross(out, up)
    w, length = SCALE_WIDTH * HEIGHT, SCALE_LEN * HEIGHT
    left = p - side * w / 2 - out * 0.01
    right = p + side * w / 2 - out * 0.01
    tip = p + up * length + out * SCALE_LIFT * HEIGHT

    def at(f):   # left and right edge points a fraction f of the way to the tip
        return left + (tip - left) * f, right + (tip - right) * f

    th = SCALE_THICK * HEIGHT
    l1, r1 = at(BANDS[0])
    l2, r2 = at(BANDS[1])
    base = slab([left, right, r1, l1], th)
    mid = slab([l1, r1, r2, l2], th)
    top = slab([l2, r2, tip], th)
    lines = kit.tube([left + out * th, tip + out * th, right + out * th], KEYLINE * HEIGHT, sections=6)
    return base, mid, top, lines


def build():
    body = egg()
    skin, mids, tips, lines = [body], [], [], []
    for t, count, offset in ROWS:
        for i in range(count):
            b, m, tp, ln = scale(t, offset + 360 * i / count)
            skin.append(b)
            mids.append(m)
            tips.append(tp)
            lines.append(ln)
    outline = kit.trimesh.util.concatenate([kit.outline_shell(body, KEYLINE * HEIGHT)] + lines)
    parts = {
        "Skin": kit.trimesh.util.concatenate(skin),
        "ScaleMid": kit.trimesh.util.concatenate(mids),
        "ScaleTip": kit.trimesh.util.concatenate(tips),
        "Outline": outline,
    }
    extras = {
        "height": HEIGHT,
        "family": "Venom",
        # Preview only: a slow turn so every side shows. Whether the fruit
        # moves in the game is still to be decided.
        "moving": [{"parts": "all", "hinge": [0, 0, 0], "axis": [0, 1, 0], "spin": 360, "cycles": 1}],
        "motionView": {"azimuth": 0, "elevation": 15},
    }
    colours = {"Skin": SKIN, "ScaleMid": MID, "ScaleTip": GREEN, "Outline": BLACK}
    return parts, colours, extras


if __name__ == "__main__":
    parts, colours, extras = build()
    info = kit.export(sys.argv[1], parts, colours, extras, flat=("ScaleMid", "ScaleTip"))
    print("size", info["size"], "triangles", info["triangles"])
    for name, p in info["parts"].items():
        print(f"  {name}: {p['triangles']} triangles")
