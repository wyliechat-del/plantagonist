"""Builds the fly from Wylie's drawing (front, three quarter and side views):
grey body, big green eyes with black pupils, a grey sucker snout, six thin
black legs and two purple wings at 60% transparency.

Usage (from the repo root):
  python3 scripts/models/build_fly.py models/Fly.glb

Measured from the side view of the drawing, with the body 450 px long:
body 450 x 310 px, eyes 250 wide x 270 tall centred on the front tip of the
body, pupils 60 px across, eyes 250 px apart centre to centre (front view).
Everything is built with the body 1 unit long and then scaled so the whole
fly (eyes to tail, wings left out) is LENGTH studs.

Parts (one MeshPart each in Studio):
  Body      grey body and snout
  Eyes      both green eyes
  Black     pupils and legs
  Outline   black cartoon outline round body, eyes and snout (delete it for
            the plain look)
  WingL/R   purple wings; set Transparency 0.6 in the game
  WingRimL/R  black edge round each wing (goes with the outline look)
The JSON written next to the GLB gives each wing's hinge point and flap axis.
"""
import math
import sys

import numpy as np

import creature_kit as kit

LENGTH = 1.5                      # studs, eyes to tail
OUTLINE = 0.03                    # outline thickness, in body units
FLAP_UP, FLAP_DOWN = 30, -45      # degrees either side of the rest pose

GREY = (98, 98, 98, 255)
GREEN = (140, 198, 63, 255)
BLACK = (0, 0, 0, 255)
PURPLE = (147, 39, 143, 102)      # alpha 102 = 60% see-through (preview only)

BODY_R = (0.36, 0.345, 0.5)       # half width, half height, half length
EYE_R = (0.27, 0.30, 0.27)
EYE_C = (0.28, 0.03, -0.47)       # right eye; the left is mirrored
PUPIL_R = 0.067
PUPIL_LOOK = (0.5, 0.05, -1.0)   # out, up, forward
HINGE = np.array([0.13, 0.29, -0.02])
WING_DIR = (0.6, 0.8, 0.6)       # up, out and back, as in the side and front views


def wing_outline(n=28):
    """Long teardrop: narrow at the hinge, round at the tip. u runs from the
    hinge along the wing, v across it."""
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        u = 0.47 + 0.43 * math.cos(t)
        pinch = min(1.0, max(0.25, 0.25 + 0.75 * (u - 0.04) / 0.5))
        v = 0.24 * math.sin(t) * pinch + 0.04 * (u - 0.04)   # leading edge a bit straighter
        pts.append((u, v))
    return pts


def leg(hip, knee, ankle, foot):
    return kit.tube([hip, knee, ankle, foot], [0.032, 0.018, 0.014], sections=5)


def build():
    body = kit.ellipsoid((0, 0, 0), BODY_R, rings=9, segments=14)
    # Snout: a short stalk under the eyes ending in a flat round pad.
    stalk = kit.tube([(0, -0.18, -0.36), (0, -0.33, -0.42), (0, -0.44, -0.50)], [0.06, 0.045], sections=8)
    pad = kit.ellipsoid((0, -0.47, -0.52), (0.09, 0.035, 0.09), rings=5, segments=10)
    eye_r = kit.ellipsoid(EYE_C, EYE_R, rings=9, segments=14)
    eye_l = kit.mirror_x(eye_r)
    # Pupils sit on the front of each eye, turned a little outward so they
    # show from the side as well as from the front (as in the drawing).
    look = np.array(PUPIL_LOOK) / np.linalg.norm(PUPIL_LOOK)
    pupil_c = np.array(EYE_C) + look * np.array(EYE_R) * 0.97
    pupil_r = kit.ellipsoid((0, 0, 0), (PUPIL_R, PUPIL_R, 0.035), rings=5, segments=10)
    pupil_r.apply_transform(kit.frame((0.0, 1.0, 0.0), -look))
    pupil_r.apply_translation(pupil_c)
    pupil_l = kit.mirror_x(pupil_r)

    # Legs hang down and back while the fly hovers. Right side, then mirrored.
    legs = []
    for z, back in ((-0.18, 0.0), (0.02, 0.12), (0.2, 0.25)):
        hip = (0.12, -0.27, z)
        knee = (0.36, -0.34, z + 0.03 + back * 0.3)
        ankle = (0.50, -0.56, z + 0.1 + back)
        foot = (0.60, -0.62, z + 0.16 + back)
        legs.append(leg(hip, knee, ankle, foot))
    legs = kit.trimesh.util.concatenate(legs + [kit.mirror_x(m) for m in legs])

    outline_2d = wing_outline()
    place = kit.frame(WING_DIR, (1.0, 0.4, -1.0))
    place[:3, 3] = HINGE
    wing_r = kit.flat_shape(outline_2d, 0.02)
    wing_r.apply_transform(place)
    rim_r = kit.ring_shape(outline_2d, 0.035, 0.03)
    rim_r.apply_transform(place)

    body_all = kit.trimesh.util.concatenate([body, stalk, pad])
    outline = kit.trimesh.util.concatenate([
        kit.outline_shell(body, OUTLINE), kit.outline_shell(eye_r, OUTLINE),
        kit.outline_shell(eye_l, OUTLINE), kit.outline_shell(stalk, OUTLINE * 0.7),
        kit.outline_shell(pad, OUTLINE * 0.7)])
    parts = {
        "Body": body_all,
        "Eyes": kit.trimesh.util.concatenate([eye_r, eye_l]),
        "Black": kit.trimesh.util.concatenate([pupil_r, pupil_l, legs]),
        "Outline": outline,
        "WingR": wing_r, "WingL": kit.mirror_x(wing_r),
        "WingRimR": rim_r, "WingRimL": kit.mirror_x(rim_r),
    }

    # Scale so eyes to tail is LENGTH studs, then sit the fly's centre on the origin.
    front = EYE_C[2] - EYE_R[2]
    scale = LENGTH / (BODY_R[2] - front)
    for m in parts.values():
        m.apply_scale(scale)
    hinge_r = HINGE * scale
    hinge_l = hinge_r * np.array([-1, 1, 1])
    extras = {
        "length": LENGTH,
        "wings": {
            # The wing turns about an axis along the body (front to back)
            # through its hinge. Positive angles lift the right wing; the
            # left wing uses the mirrored angle.
            "WingR": {"hinge": hinge_r.round(3).tolist(), "axis": [0, 0, 1], "sign": 1, "rim": "WingRimR"},
            "WingL": {"hinge": hinge_l.round(3).tolist(), "axis": [0, 0, 1], "sign": -1, "rim": "WingRimL"},
            "flapUp": FLAP_UP, "flapDown": FLAP_DOWN,
        },
        "transparentParts": {"WingR": 0.6, "WingL": 0.6},
    }
    colours = {"Body": GREY, "Eyes": GREEN, "Black": BLACK, "Outline": BLACK,
               "WingR": PURPLE, "WingL": PURPLE, "WingRimR": BLACK, "WingRimL": BLACK}
    return parts, colours, extras


if __name__ == "__main__":
    parts, colours, extras = build()
    info = kit.export(sys.argv[1], parts, colours, extras)
    print("size", info["size"], "triangles", info["triangles"])
    for name, p in info["parts"].items():
        print(f"  {name}: {p['triangles']} triangles")
