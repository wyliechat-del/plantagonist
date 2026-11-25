"""Builds the Cow Poo pickup, designed from Wylie's brief: a coil that spirals
up to a peak in the middle (like piped icing), sitting on a flat splat, in
a1633b and 653a2a with the black keyline.

Usage (from the repo root):
  python3 scripts/models/build_poo.py models/creatures/CowPoo.glb

Size (Wylie): 1.3 times the placeholder, which is a disc 2.2 studs across,
so WIDTH is 2.86 studs. It doesn't move while it sits there (Wylie).

When a plant runs over it (Wylie): it squashes flat while blobs shoot out,
land as little splats and shrink away, then the poo shrinks away too. The
blobs are hidden until then. This is listed in the JSON under "moving" with
"onEvent": "runOver", as keyframes the game can play with tweens:
"keys": [[time 0..1, offset from hinge [x, y, z], scale [x, y, z]], ...].

Parts:
  Coil     light brown spiral (a1633b)
  Core     dark brown inside, showing in the grooves between turns (653a2a)
  Splat    dark brown flat base with a wobbly edge (653a2a)
  Outline  black keyline round coil and splat
  Blob1-8, BlobRim1-8  splat blobs and their keylines (hidden until run over)
"""
import math
import sys

import numpy as np

import creature_kit as kit

WIDTH = 2.2 * 1.3            # studs across the splat
TURNS = 2.6                  # turns of the coil from the bottom to the peak
COIL_R = 0.96                # studs, middle of the bottom turn from the centre
TUBE_W = 0.38                # studs, half width of the coil at the bottom
TUBE_H = 0.3                 # studs, half height of the coil at the bottom (a bit flat, like icing)
COIL_TOP = 0.72              # studs, height of the coil's middle where it reaches the centre
PEAK = 1.4                   # studs, tip of the peak
SPLAT_THICK = 0.14
KEYLINE_W = 0.03

LIGHT = (161, 99, 59, 255)   # a1633b
DARK = (101, 58, 42, 255)    # 653a2a
BLACK = (0, 0, 0, 255)


def coil():
    pts, ws, hs = [], [], []
    steps = 170
    for k in range(steps + 1):
        s = k / steps
        turns = TURNS * s
        a = 2 * math.pi * turns
        # The first turn goes all the way round at nearly full size, so the coil
        # covers the splat evenly on every side (and the next turn sits just
        # inside it, so its round end shows); then it spirals in.
        first = 0.2                                         # studs the first turn moves in
        r = COIL_R - first * turns if turns < 1 else (COIL_R - first) * (1 - (turns - 1) / (TURNS - 1))
        shrink = 1 - 0.45 * s
        y = SPLAT_THICK + TUBE_H + (COIL_TOP - TUBE_H - SPLAT_THICK) * s
        pts.append([r * math.sin(a), y, -r * math.cos(a)])
        ws.append(TUBE_W * shrink)
        hs.append(TUBE_H * shrink)
    # A round end on the outside of the coil (half an oval, not cut off flat).
    back = np.array(pts[0]) - np.array(pts[1])
    back /= np.linalg.norm(back)
    cap = []
    for k in range(1, 9):
        x = k / 8
        f = math.sqrt(max(1 - x * x, 0)) * 0.98 + 0.02
        cap.append((list(np.array(pts[0]) + back * TUBE_W * 0.9 * x), TUBE_W * f, TUBE_H * f))
    for p, w, h in cap:
        pts.insert(0, p)
        ws.insert(0, w)
        hs.insert(0, h)
    # The end keeps turning a little as it rises into a soft pointed peak.
    w_end, last_a = ws[-1], 2 * math.pi * TURNS
    n = 12
    for k in range(1, n + 1):
        s = k / n
        a = last_a + s * 2.2
        r = 0.1 * math.sin(math.pi * s)
        pts.append([r * math.sin(a), COIL_TOP + (PEAK - COIL_TOP) * s, -r * math.cos(a)])
        w = w_end * math.cos(math.pi / 2 * s) ** 0.8 + 0.01
        ws.append(w)
        hs.append(w)
    return kit.sweep(pts, ws, hs, sections=14)


def core():
    """Dark cone inside the coil, so the grooves between turns look dark."""
    prof = [(0, SPLAT_THICK), (COIL_R * 0.95, SPLAT_THICK), (COIL_R * 0.7, 0.42),
            (COIL_R * 0.35, 0.6), (0.1, COIL_TOP), (0, COIL_TOP + 0.05)]
    return kit.lathe(prof, sections=28)


def splat():
    n = 60
    outline = []
    for i in range(n):
        a = 2 * math.pi * i / n
        r = WIDTH / 2 * (0.93 + 0.04 * math.sin(5 * a + 0.4) + 0.03 * math.sin(9 * a + 1.3))
        outline.append((r * math.cos(a), r * math.sin(a)))
    m = kit.flat_shape(outline, SPLAT_THICK)
    m.vertices = np.array([[u, z + SPLAT_THICK / 2, v] for u, v, z in m.vertices])
    m.fix_normals()
    return m


BLOBS = 8
SPLAT_TIME = 1.2             # seconds for the whole splat


def blobs():
    """Little blobs that fly out from the poo: (blob, keyline, start, keys)."""
    rng = np.random.default_rng(7)
    out = []
    for i in range(BLOBS):
        a = 2 * math.pi * (i + rng.uniform(-0.25, 0.25)) / BLOBS
        size = rng.uniform(0.1, 0.34)           # Wylie: ovals of different sizes
        stretch = rng.uniform(1.3, 1.9)
        start = np.array([0.45 * math.sin(a), 0.45, -0.45 * math.cos(a)])
        dist = rng.uniform(1.9, 3.0)
        land = np.array([dist * math.sin(a), size * 0.25, -dist * math.cos(a)]) - start
        top = land * 0.5 + np.array([0, rng.uniform(0.6, 1.0), 0])
        m = kit.ellipsoid([0, 0, 0], (size * stretch, size * 0.8, size), rings=8, segments=12)
        m = kit.rotate_about(m, rng.uniform(0, 180), (0, 1, 0), (0, 0, 0))
        m.apply_translation(start)
        rim = kit.outline_shell(m, KEYLINE_W * 0.8)
        r = lambda v: [round(float(x), 3) for x in v]
        keys = [[0.0, [0, 0, 0], [0, 0, 0]],
                [0.08, r(land * 0.15 + [0, 0.25, 0]), [1, 1, 1]],
                [0.3, r(top), [1, 1.1, 1]],
                [0.5, r(land), [1.6, 0.3, 1.6]],      # lands and spreads into a splat
                [0.75, r(land), [1.6, 0.3, 1.6]],
                [1.0, r(land), [0, 0, 0]]]
        out.append((m, rim, start, keys))
    return out


def build():
    c, base = coil(), splat()
    parts = {
        "Coil": c,
        "Core": core(),
        "Splat": base,
        "Outline": kit.trimesh.util.concatenate([kit.outline_shell(c, KEYLINE_W),
                                                 kit.outline_shell(base, KEYLINE_W)]),
    }
    colours = {"Coil": LIGHT, "Core": DARK, "Splat": DARK, "Outline": BLACK}
    moving = [
        # The poo squashes flat and wide as it is run over, then shrinks away.
        {"parts": ["Coil", "Core", "Splat", "Outline"], "hinge": [0, 0, 0], "onEvent": "runOver",
         "keys": [[0.0, [0, 0, 0], [1, 1, 1]], [0.12, [0, 0, 0], [1.3, 0.25, 1.3]],
                  [0.6, [0, 0, 0], [1.3, 0.25, 1.3]], [0.9, [0, 0, 0], [0, 0, 0]], [1.0, [0, 0, 0], [0, 0, 0]]]},
    ]
    for k, (m, rim, start, keys) in enumerate(blobs(), 1):
        parts[f"Blob{k}"], parts[f"BlobRim{k}"] = m, rim
        colours[f"Blob{k}"], colours[f"BlobRim{k}"] = LIGHT if k % 3 == 0 else DARK, BLACK
        moving.append({"parts": [f"Blob{k}", f"BlobRim{k}"], "hinge": [round(float(v), 3) for v in start],
                       "onEvent": "runOver", "hiddenAtRest": True, "keys": keys})
    extras = {"width": round(WIDTH, 3), "replaces": "CowPoo placeholder (cylinder 2.2 across)",
              "moving": moving, "eventSeconds": SPLAT_TIME, "motionFrames": 30,
              "motionView": {"azimuth": -30, "elevation": 35, "zoom": 2.1}}
    return parts, colours, extras


if __name__ == "__main__":
    parts, colours, extras = build()
    info = kit.export(sys.argv[1], parts, colours, extras)
    print("size", info["size"], "triangles", info["triangles"])
