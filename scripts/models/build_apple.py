"""Builds the Red Apple (the Slash family's fruit) from Wylie's drawing: a
red apple with a dip at the top, a brown stem, a green leaf, a happy face
(round eyes and a crooked smile) and a black keyline.

Usage (from the repo root):
  python3 scripts/models/build_apple.py models/creatures/AppleSlash.glb

Measured from the drawing in pixels: the apple is 721 px wide, its bottom
at y 1375, its middle at x 977. Heights in the profile are pixels up from
the bottom. The model is scaled so the apple (without stem and leaf) is
HEIGHT studs tall, the same as the dragonfruit.

Motion (Wylie): the same bounce as the dragonfruit, and the leaf flaps up
and down LEAF_FLAP degrees about where it meets the stem as it bounces.

Parts:
  Apple    red body
  Stem     brown stem
  Leaf     green leaf (moves)
  Eyes     white of the eyes
  Outline  black keyline round apple, stem and eyes, plus pupils, eye rims,
           smile and the lines round the dip at the top
  LeafRim  black keyline round the leaf (moves with it)
"""
import math
import sys

import numpy as np

import creature_kit as kit

HEIGHT = 2.0                 # studs, apple body only
BOUNCE_HEIGHT = 0.3          # studs, how high each hop goes
BOUNCE_SQUASH = 0.8          # height on landing, as a share of full height
LEAF_FLAP = 15               # degrees up and down from the drawn pose

RED = (193, 39, 45, 255)
BROWN = (115, 52, 22, 255)
GREEN = (140, 198, 63, 255)
WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)

CENTRE_X, BOTTOM_Y = 977, 1375
# Side profile (radius, height up from the bottom), px. Flat-ish bottom,
# widest a third of the way up, rounded shoulders, then a dip in the top.
PROFILE = [(0, 0), (65, 2), (150, 25), (223, 75), (275, 130), (313, 175), (340, 240),
           (355, 300), (360, 405), (352, 480), (323, 525), (280, 580), (243, 615),
           (190, 655), (130, 685), (70, 700), (35, 690), (0, 655)]
TOP_INDEX = 15               # the highest point of the profile (start of the dip)
PX = HEIGHT / 700            # studs per drawing pixel
KEYLINE_W = 0.018 * 2.0      # same keyline as the dragonfruit

EYES = [((837, 1010), 108), ((1112, 1010), 108)]
PUPILS = [((837, 1012), 52), ((1112, 1012), 52)]
SMILE = [(888, 1220), (920, 1237), (952, 1243), (990, 1235), (1025, 1214), (1052, 1190)]
SMILE_TICK = [(1042, 1145), (1044, 1168), (1055, 1190), (1075, 1200), (1097, 1203)]
# Curved lines round the dip at the top.
TOP_LINES = [[(790, 720), (850, 713), (900, 722), (960, 752)],
             [(1000, 745), (1050, 720), (1100, 707), (1150, 718), (1205, 748)],
             [(1000, 752), (1035, 760), (1060, 780), (1083, 805)]]
STEM = [(970, 715), (978, 680), (985, 640), (995, 605)]
# Leaf traced from the drawing, starting where it meets the stem.
LEAF = [(975, 668), (940, 620), (880, 560), (820, 515), (760, 490), (710, 485), (660, 492),
        (600, 520), (550, 560), (505, 600), (560, 588), (585, 585), (610, 600), (650, 635),
        (700, 668), (760, 688), (820, 693), (900, 686)]


def radius_at(h_studs):
    """Outer radius of the apple at a height (studs), ignoring the dip."""
    outer = PROFILE[:TOP_INDEX + 1]
    return float(np.interp(h_studs / PX, [p[1] for p in outer], [p[0] for p in outer])) * PX


on_face = kit.front_mapper(radius_at, CENTRE_X, BOTTOM_Y, PX)


def model_point(x, y, z_px=0.0):
    """Drawing pixel to model space, z_px towards the back."""
    return np.array([-(x - CENTRE_X) * PX, (BOTTOM_Y - y) * PX, z_px * PX])


def build():
    apple = kit.lathe([(r * PX, h * PX) for r, h in PROFILE], sections=32)
    stem_pts = [model_point(x, y) for x, y in STEM]
    stem = kit.tube(stem_pts, [22 * PX, 20 * PX, 19 * PX], sections=10)
    stem = kit.trimesh.util.concatenate([stem, kit.ellipsoid(stem_pts[-1], (19 * PX,) * 3, rings=6, segments=10)])

    # Leaf: flat, facing the front, a little in front of the stem.
    leaf2d = [(x, y) for x, y in LEAF]
    leaf = kit.flat_shape(leaf2d, 8)
    leaf_rim = kit.ring_shape(leaf2d, KEYLINE_W / PX, 12)
    for m in (leaf, leaf_rim):
        m.vertices = np.array([model_point(x, y, -30 + z) for x, y, z in m.vertices])
        m.fix_normals()
    hinge = model_point(*LEAF[0], -30)

    whites, blacks = [], []
    rim_px = KEYLINE_W / PX
    for c, r in EYES:
        eye = kit.circle(c, r)
        whites.append(kit.bend_onto(on_face, eye, 4, 4))
        blacks.append(kit.bend_onto(on_face, eye, 7, 4, ring_px=rim_px))
    for c, r in PUPILS:
        blacks.append(kit.bend_onto(on_face, kit.circle(c, r, 32), 6, 4))
    for line in [SMILE, SMILE_TICK] + TOP_LINES:
        blacks.append(kit.tube([on_face(x, y, 4) for x, y in line], KEYLINE_W * 0.35, sections=6))

    outline = kit.trimesh.util.concatenate(
        [kit.outline_shell(apple, KEYLINE_W), kit.outline_shell(stem, KEYLINE_W * 0.6)] + blacks)
    parts = {
        "Apple": apple,
        "Stem": stem,
        "Leaf": leaf,
        "Eyes": kit.trimesh.util.concatenate(whites),
        "Outline": outline,
        "LeafRim": leaf_rim,
    }
    extras = {
        "height": HEIGHT,
        "family": "Slash",
        "moving": [
            # Same bounce as the dragonfruit: a small hop, then a squish to
            # 80% height from the base on landing.
            {"parts": "all", "hinge": [0, 0, 0], "cycles": 1,
             "bounce": {"height": BOUNCE_HEIGHT, "squash": BOUNCE_SQUASH, "squashShare": 0.3}},
            # Leaf flaps about where it meets the stem (front-to-back axis):
            # down LEAF_FLAP at landing, up LEAF_FLAP at the top of the hop.
            {"parts": ["Leaf", "LeafRim"], "hinge": hinge.round(3).tolist(), "axis": [0, 0, 1],
             "from": -LEAF_FLAP, "to": LEAF_FLAP, "cycles": 1},
        ],
        "motionFrames": 30,
        "motionView": {"azimuth": 0, "elevation": 10},
    }
    colours = {"Apple": RED, "Stem": BROWN, "Leaf": GREEN, "Eyes": WHITE, "Outline": BLACK, "LeafRim": BLACK}
    return parts, colours, extras


if __name__ == "__main__":
    parts, colours, extras = build()
    info = kit.export(sys.argv[1], parts, colours, extras, flat=("Leaf",))
    print("size", info["size"], "triangles", info["triangles"])
    for name, p in info["parts"].items():
        print(f"  {name}: {p['triangles']} triangles")
