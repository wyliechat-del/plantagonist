"""Builds the Purple Dragonfruit (the Venom family's fruit) from Wylie's
drawing: a magenta egg covered in pointed scales that fade from magenta at
the base to green at the tip, with a black keyline.

Usage (from the repo root):
  python3 scripts/models/build_dragonfruit.py models/creatures/DragonfruitVenom.glb

Measured from the drawing: the egg is 730 x 1050 px, a little fuller at the
bottom. Scales are triangles about a quarter of the egg's height, pointing
up, with their tips lifted off the skin; the top ones stick up past the top.
The model is HEIGHT studs tall (egg only) and sits on the origin.

Roblox parts are one colour each, so the scale's fade is done in bands: the
lower part of each scale is the skin itself inside its keyline, then a thin
brown band (ScaleMid) where it lifts off, then a big green tip (ScaleTip).
Round 2 (Wylie): same keyline on egg and scales, no dark band at the base of
the scales, bigger green tips, thinner brown band, slower spin.

Parts:
  Skin      magenta egg (the lower part of each scale is just skin)
  ScaleMid  thin brown band where each scale lifts off
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
SCALE_LIFT = 0.08            # how far the tip stands off the skin, times HEIGHT
SCALE_THICK = 0.012          # times HEIGHT
LIFT_FROM = 0.3             # how far up the scale it starts to rise off the skin
BAND = 0.14                  # brown band, as a share of the raised part; the rest is green
KEYLINE = 0.018              # keyline width, times HEIGHT (same on the egg and the scales)
KEYLINE_W = KEYLINE * HEIGHT


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


def off_skin(q, extra, out):
    """Push a point out (from the middle) so it sits `extra` above the skin.
    Points past the top of the egg just move `extra` along the scale's `out`."""
    t = q[1] / HEIGHT
    if t >= 0.98 or t <= 0:
        return np.array(q, float) + out * extra
    a = math.atan2(q[0], -q[2])
    r = max(math.hypot(q[0], q[2]), egg_radius(t)) + extra
    return np.array([r * math.sin(a), q[1], -r * math.cos(a)])


def scale(t, angle):
    """One scale. The lower part is just the skin with a keyline round it,
    so it blends in. From LIFT_FROM up, the scale lifts off the skin, bending
    with it: a thin brown band, then a big green tip."""
    p, out, up = surface(t, angle)
    side = np.cross(out, up)
    w, length = SCALE_WIDTH * HEIGHT, SCALE_LEN * HEIGHT
    corners = (p - side * w / 2, p + side * w / 2)
    flat_tip = p + up * length
    th = SCALE_THICK * HEIGHT

    def lift(f):   # height above the skin a fraction f up the scale
        if f <= LIFT_FROM:
            return 0.0
        return SCALE_LIFT * HEIGHT * (f - LIFT_FROM) / (1 - LIFT_FROM)

    def point(corner, f, extra=0.0):
        return off_skin(corner + (flat_tip - corner) * f, lift(f) + extra, out)

    f1 = LIFT_FROM + BAND * (1 - LIFT_FROM)    # where green starts
    f2 = (f1 + 1) / 2
    sink = -th / 2   # the flap's lower edge starts just under the skin, so no gap shows

    def row(f, extra=0.0):
        return [point(c, f, extra) for c in corners]

    (l0, r0), (l1, r1), (l2, r2) = row(LIFT_FROM, sink), row(f1), row(f2)
    tip = point(corners[0], 1.0)
    mid = slab([l0, r0, r1, l1], th)
    top = kit.trimesh.util.concatenate([slab([l1, r1, r2, l2], th), slab([l2, r2, tip], th)])
    # Keyline up each side to the tip, sitting on top of the skin and flap.
    fs = [LIFT_FROM * i / 3 for i in range(4)] + [f1, f2]
    k = KEYLINE_W / 2 + th / 2
    left = [point(corners[0], f, k) for f in fs]
    right = [point(corners[1], f, k) for f in fs]
    lines = kit.tube(left + [point(corners[0], 1.0, k)] + right[::-1], KEYLINE_W / 2, sections=5)
    return mid, top, lines


def build():
    body = egg()
    mids, tips, lines = [], [], []
    for t, count, offset in ROWS:
        for i in range(count):
            m, tp, ln = scale(t, offset + 360 * i / count)
            mids.append(m)
            tips.append(tp)
            lines.append(ln)
    outline = kit.trimesh.util.concatenate([kit.outline_shell(body, KEYLINE_W)] + lines)
    parts = {
        "Skin": body,
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
        "motionFrames": 107,   # one turn in about 4.3 seconds (Wylie: 30% of the first speed),
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
