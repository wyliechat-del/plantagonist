"""Builds the Cow Poo pickup, designed from Wylie's brief: a coil that spirals
up to a peak in the middle (like piped icing), sitting on a flat splat, in
a1633b and 653a2a with the black keyline.

Usage (from the repo root):
  python3 scripts/models/build_poo.py models/creatures/CowPoo.glb

Size (Wylie): 1.3 times the placeholder, which is a disc 2.2 studs across,
so WIDTH is 2.86 studs. It doesn't move.

Parts:
  Coil     light brown spiral (a1633b)
  Core     dark brown inside, showing in the grooves between turns (653a2a)
  Splat    dark brown flat base with a wobbly edge (653a2a)
  Outline  black keyline round coil and splat
"""
import math
import sys

import numpy as np

import creature_kit as kit

WIDTH = 2.2 * 1.3            # studs across the splat
TURNS = 2.4                  # turns of the coil from the bottom to the peak
COIL_R = 0.96                # studs, middle of the bottom turn from the centre
TUBE_W = 0.38                # studs, half width of the coil at the bottom
TUBE_H = 0.3                 # studs, half height of the coil at the bottom (a bit flat, like icing)
COIL_TOP = 1.15              # studs, height of the coil's middle where it reaches the centre
PEAK = 1.7                   # studs, tip of the peak
SPLAT_THICK = 0.14
KEYLINE_W = 0.03

LIGHT = (161, 99, 59, 255)   # a1633b
DARK = (101, 58, 42, 255)    # 653a2a
BLACK = (0, 0, 0, 255)


def coil():
    pts, ws, hs = [], [], []
    steps = 150
    for k in range(steps + 1):
        s = k / steps
        a = 2 * math.pi * TURNS * s
        r = COIL_R * (1 - s)
        shrink = 1 - 0.45 * s
        start = min(1, 0.55 + s / 0.08 * 0.45)              # the start tucks into the splat
        y = SPLAT_THICK + TUBE_H * start + (COIL_TOP - TUBE_H - SPLAT_THICK) * s
        pts.append([r * math.sin(a), y, -r * math.cos(a)])
        ws.append(TUBE_W * shrink * start)
        hs.append(TUBE_H * shrink * start)
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
    prof = [(0, SPLAT_THICK), (COIL_R * 0.95, SPLAT_THICK), (COIL_R * 0.7, 0.5),
            (COIL_R * 0.35, 0.85), (0.1, COIL_TOP), (0, COIL_TOP + 0.05)]
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
    extras = {"width": round(WIDTH, 3), "replaces": "CowPoo placeholder (cylinder 2.2 across)"}
    return parts, colours, extras


if __name__ == "__main__":
    parts, colours, extras = build()
    info = kit.export(sys.argv[1], parts, colours, extras)
    print("size", info["size"], "triangles", info["triangles"])
