"""Builds the acorn (the game's Nut) from Wylie's drawing (side and front
views): a brown nut with a pointed tip, a dark brown cap with a curly stem,
an oak leaf, two white eyes with black pupils and a crooked smile.

Usage (from the repo root):
  python3 scripts/models/build_nut.py models/creatures/Nut.glb

Measured from the front view of the drawing in pixels: the cap is 570 px
wide and the whole acorn, tip to cap top, 615 px tall. Heights below are
pixels up from the tip. The model is scaled so the cap is CAP_WIDTH studs
wide (Wylie: twice the old 1 stud nut).

The tip sits on the origin, which is also the pivot for rocking: the acorn
rocks ROCK degrees either side of upright on its tip, shrinking by SHRINK at
the ends of each rock and back to full size when upright.

Parts (one MeshPart each in Studio):
  Nut      light brown nut
  Cap      dark brown cap and curly stem
  Leaf     green oak leaf
  Eyes     white eyes
  Black    pupils and mouth
  Outline  black keyline round nut, cap, stem, eyes and leaf
"""
import math
import sys

import numpy as np

import creature_kit as kit

CAP_WIDTH = 2.0          # studs
ROCK = 15                # degrees either side of upright
SHRINK = 0.15            # 15% smaller at the ends of each rock
ROCKS_PER_LOOP = 1
OUTLINE = 6              # keyline thickness, px

NUT = (161, 99, 60, 255)
CAP = (101, 56, 41, 255)
GREEN = (140, 198, 63, 255)
WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)

# Nut: (radius, height) from the tip up. The top is hidden inside the cap.
NUT_PROFILE = [(0, 0), (45, 25), (115, 105), (180, 205), (212, 305), (222, 400),
               (224, 470), (214, 520), (180, 570), (100, 603), (0, 612)]
# Cap: profile at its sides, from the middle of the underside out to the rim,
# then up the outside to the top. At the front and back the rim is raised
# (see CAP_RIM_FRONT), so the cap dips down over the sides like a beret.
CAP_PROFILE = [(0, 470), (200, 385), (232, 362), (262, 358), (284, 395), (288, 450),
               (276, 520), (240, 580), (160, 625), (0, 642)]
CAP_TOP, CAP_RIM_SIDE, CAP_RIM_FRONT = 642, 358, 530
EYE_X, EYE_H, EYE_R = 95, 343, 62
PUPIL_R = 28
# Mouth: a crooked smile with a little tick at the right end (front view).
MOUTH = [(80, 175), (45, 163), (5, 170), (-30, 192), (-50, 213)]
MOUTH_TICK = [(-35, 250), (-42, 228), (-50, 213), (-68, 210), (-85, 211)]
# Stem: rises from the cap top and curls over to the left (front view).
# (+x shows on the left of the front view, because the acorn faces -Z.)
STEM = [(-55, 625), (-80, 675), (-85, 740), (-65, 795), (-20, 825), (35, 823),
        (75, 790), (85, 740), (65, 708), (45, 705)]


def nut_radius(h):
    hs = [p[1] for p in NUT_PROFILE]
    rs = [p[0] for p in NUT_PROFILE]
    return float(np.interp(h, hs, rs))


def on_front(x, h, lift=4):
    """A point on the front of the nut, `lift` px out from its surface."""
    r = nut_radius(h)
    z = -math.sqrt(max(r * r - x * x, 0)) - lift
    return (x, h, z)


def leaf_outline(n=60):
    """Oak leaf: an oval with five round lobes down each side, narrow stalk end
    at u = 0. u along the leaf, v across it (px)."""
    pts = []
    length, width = 300, 175
    for i in range(n):
        t = 2 * math.pi * i / n
        lobes = 1 + 0.13 * math.cos(10 * t)
        u = length / 2 * (1 + math.cos(t) * lobes)
        v = width / 2 * math.sin(t) * lobes * min(1, 0.35 + u / 120)
        pts.append((u, v))
    return pts


def build():
    nut = kit.lathe(NUT_PROFILE, sections=24)
    cap = kit.lathe(CAP_PROFILE, sections=32)
    # Raise the rim at the front and back: full depth at the sides (x),
    # CAP_RIM_FRONT at the front and back (z), smooth in between.
    v = cap.vertices.copy()
    side = v[:, 0] ** 2 / np.maximum(v[:, 0] ** 2 + v[:, 2] ** 2, 1e-9)
    keep = (CAP_TOP - CAP_RIM_FRONT) / (CAP_TOP - CAP_RIM_SIDE)
    v[:, 1] = CAP_TOP - (CAP_TOP - v[:, 1]) * (keep + (1 - keep) * side)
    cap.vertices = v

    stem_pts = [(x, h, 0) for x, h in STEM]
    stem = kit.tube(stem_pts, [30, 28, 26, 24, 22, 21, 20, 19, 18], sections=10)
    stem_end = kit.ellipsoid(stem_pts[-1], (18, 18, 18), rings=6, segments=10)
    stem = kit.trimesh.util.concatenate([stem, stem_end])

    # Leaf grows from the stem base, up and to the right, turned 35 degrees
    # so it shows from the front and from the side.
    outline_2d = leaf_outline()
    place = kit.frame((-0.8, 0.6, 0.0), (0.0, 0.0, -1.0))
    place = kit.trimesh.transformations.rotation_matrix(math.radians(-35), (0, 1, 0)) @ place
    place[:3, 3] = (-70, 635, 10)
    leaf = kit.flat_shape(outline_2d, 8)
    leaf.apply_transform(place)
    leaf_rim = kit.ring_shape(outline_2d, 9, 12)
    leaf_rim.apply_transform(place)

    eyes, pupils = [], []
    for side in (-1, 1):
        x = side * EYE_X
        c = on_front(x, EYE_H, lift=-6)
        normal = np.array([x, 0, c[2]]) / math.hypot(x, c[2])
        eye = kit.ellipsoid((0, 0, 0), (EYE_R, EYE_R, 18), rings=8, segments=16)
        eye.apply_transform(kit.frame((0, 1, 0), -normal))
        eye.apply_translation(c)
        eyes.append(eye)
        pupil = kit.ellipsoid((0, 0, 0), (PUPIL_R, PUPIL_R, 6), rings=5, segments=12)
        pupil.apply_transform(kit.frame((0, 1, 0), -normal))
        pupil.apply_translation(np.array(c) + normal * 14)
        pupils.append(pupil)
    mouth = kit.tube([on_front(x, h) for x, h in MOUTH], 6, sections=6)
    tick = kit.tube([on_front(x, h) for x, h in MOUTH_TICK], 6, sections=6)

    outline = kit.trimesh.util.concatenate(
        [kit.outline_shell(nut, OUTLINE), kit.outline_shell(cap, OUTLINE),
         kit.outline_shell(stem, OUTLINE)] + [kit.outline_shell(e, OUTLINE) for e in eyes] + [leaf_rim])
    parts = {
        "Nut": nut,
        "Cap": kit.trimesh.util.concatenate([cap, stem]),
        "Leaf": leaf,
        "Eyes": kit.trimesh.util.concatenate(eyes),
        "Black": kit.trimesh.util.concatenate(pupils + [mouth, tick]),
        "Outline": outline,
    }
    scale = CAP_WIDTH / (2 * max(r for r, _ in CAP_PROFILE))
    for m in parts.values():
        m.apply_scale(scale)
    extras = {
        "capWidth": CAP_WIDTH,
        "motionView": {"azimuth": 0, "elevation": 8},   # rocking reads best from the front
        "moving": [
            # The whole acorn rocks side to side on its tip (the origin).
            {"parts": "all", "hinge": [0, 0, 0], "axis": [0, 0, 1],
             "swing": ROCK, "shrink": SHRINK, "cycles": ROCKS_PER_LOOP},
        ],
    }
    colours = {"Nut": NUT, "Cap": CAP, "Leaf": GREEN, "Eyes": WHITE, "Black": BLACK, "Outline": BLACK}
    return parts, colours, extras


if __name__ == "__main__":
    parts, colours, extras = build()
    info = kit.export(sys.argv[1], parts, colours, extras)
    print("size", info["size"], "triangles", info["triangles"])
    for name, p in info["parts"].items():
        print(f"  {name}: {p['triangles']} triangles")
