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


# Oak leaf traced from the front view of the drawing (drawing pixels), from
# the stalk round the lobes and back.
LEAF_TRACE = [(1465, 640), (1445, 625), (1475, 595), (1490, 560), (1490, 520), (1480, 480),
              (1475, 440), (1490, 420), (1515, 412), (1530, 425), (1540, 460), (1550, 465),
              (1558, 440), (1565, 410), (1585, 395), (1605, 400), (1615, 420), (1625, 430),
              (1640, 425), (1660, 408), (1680, 405), (1695, 420), (1690, 440), (1670, 460),
              (1665, 475), (1680, 490), (1700, 500), (1700, 520), (1685, 535), (1640, 545),
              (1625, 550), (1635, 565), (1670, 575), (1680, 590), (1670, 610), (1640, 620),
              (1600, 618), (1560, 610), (1525, 603), (1500, 610), (1480, 625)]
DRAWING_CENTRE_X, DRAWING_TIP_Y = 1385, 1205


def leaf_outline():
    """The traced leaf as (x, height) in model pixels, smoothed so the lobes
    stay round. +x shows on the left of the front view, so x is flipped."""
    pts = np.array([(-(x - DRAWING_CENTRE_X), DRAWING_TIP_Y - y) for x, y in LEAF_TRACE], float)
    # Two rounds of corner cutting turn the traced corners into curves.
    for _ in range(2):
        a, b = pts, np.roll(pts, -1, axis=0)
        pts = np.stack([0.75 * a + 0.25 * b, 0.25 * a + 0.75 * b], axis=1).reshape(-1, 2)
    return [tuple(p) for p in pts]


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
    # Thick curl (Wylie: thicker than the drawing), tapering a little to a round end.
    stem = kit.tube(stem_pts, [44, 42, 40, 38, 36, 34, 33, 32, 31], sections=12)
    stem_end = kit.ellipsoid(stem_pts[-1], (31, 31, 31), rings=6, segments=12)
    stem = kit.trimesh.util.concatenate([stem, stem_end])

    # Leaf: drawn flat facing the front, then turned 20 degrees about its
    # stalk so it still shows from the side.
    outline_2d = leaf_outline()
    stalk = np.array([-(LEAF_TRACE[0][0] - DRAWING_CENTRE_X), DRAWING_TIP_Y - LEAF_TRACE[0][1], 0.0])
    place = kit.trimesh.transformations.rotation_matrix(math.radians(-20), (0, 1, 0), stalk)
    place = place @ kit.trimesh.transformations.translation_matrix((0, 0, -48))   # in front of the stem, as drawn
    flip = np.diag([1.0, 1.0, -1.0, 1.0])   # face the front (-Z)
    leaf = kit.flat_shape(outline_2d, 8)
    leaf.apply_transform(place @ flip)
    leaf_rim = kit.ring_shape(outline_2d, 10, 12)   # black keyline round the leaf
    leaf_rim.apply_transform(place @ flip)

    eyes, pupils = [], []
    for side in (-1, 1):
        x = side * EYE_X
        c = on_front(x, EYE_H, lift=10)   # stands out so the whole round edge shows
        normal = np.array([x, 0, c[2]]) / math.hypot(x, c[2])
        eye = kit.ellipsoid((0, 0, 0), (EYE_R, EYE_R, 22), rings=8, segments=16)
        eye.apply_transform(kit.frame((0, 1, 0), -normal))
        eye.apply_translation(c)
        eyes.append(eye)
        pupil = kit.ellipsoid((0, 0, 0), (PUPIL_R, PUPIL_R, 6), rings=5, segments=12)
        pupil.apply_transform(kit.frame((0, 1, 0), -normal))
        pupil.apply_translation(np.array(c) + normal * 20)
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
    info = kit.export(sys.argv[1], parts, colours, extras, flat=("Leaf",))
    print("size", info["size"], "triangles", info["triangles"])
    for name, p in info["parts"].items():
        print(f"  {name}: {p['triangles']} triangles")
