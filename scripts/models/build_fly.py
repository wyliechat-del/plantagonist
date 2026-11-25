"""Builds the fly from Wylie's drawing (front, three quarter and side views):
grey body, big green eyes with black pupils, a grey trumpet shaped snout,
six thin black legs trailing behind and two purple wings at 60% transparency.
Round 2 changes from Wylie (2026-11-25): black keyline kept, legs further
back and trailing (middle leg 1.5 times longer), wings uneven (long arc on
top, shallow arc underneath), simple trumpet snout, eyes 1.5 times bigger.

Usage (from the repo root):
  python3 scripts/models/build_fly.py models/creatures/Fly.glb

Measured from the side view of the drawing, with the body 450 px long:
body 450 x 310 px, eyes 250 wide x 270 tall centred on the front tip of the
body, pupils 60 px across, eyes 250 px apart centre to centre (front view).
Everything is built with the body 1 unit long and then scaled so the body
is BODY_LENGTH studs long.

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

BODY_LENGTH = 1.2                 # studs, body only (eyes and wings stick out)
OUTLINE = 0.03                    # outline thickness, in body units
FLAP_UP, FLAP_DOWN = 30, -45      # degrees either side of the rest pose

GREY = (98, 98, 98, 255)
GREEN = (140, 198, 63, 255)
BLACK = (0, 0, 0, 255)
PURPLE = (147, 39, 143, 102)      # alpha 102 = 60% see-through (preview only)

BODY_R = (0.36, 0.345, 0.5)       # half width, half height, half length
EYE_SIZE = 1.5                    # Wylie: eyes 1.5 times the drawing's size
EYE_R = (0.27 * EYE_SIZE, 0.30 * EYE_SIZE, 0.27 * EYE_SIZE)
EYE_C = (0.27 * EYE_SIZE, 0.08, -0.62)   # right eye; the left is mirrored. The eyes touch in the middle.
PUPIL_R = 0.067 * EYE_SIZE
PUPIL_LOOK = (0.5, 0.05, -1.0)   # out, up, forward
HINGE = np.array([0.12, 0.31, 0.04])
WING_DIR = (0.6, 0.8, 0.6)       # up, out and back, as in the side and front views


WING_LEN = 0.95
WING_TOP, WING_BOTTOM = 0.95, 0.28   # how far each edge bulges (top edge is the long arc)


def wing_outline(n=16):
    """Uneven wing as in the drawing: narrow at the hinge, a long high arc on
    the top edge and a shallow arc underneath, meeting in a round tip.
    u runs from the hinge along the wing, v across it (+v is the top edge
    once the wing is placed)."""
    def bulge(u):
        return u ** 0.8 * (1 - u) ** 0.5
    us = [(i / n) ** 0.85 for i in range(n + 1)]
    top = [(u * WING_LEN, (0.015 + WING_TOP * bulge(u)) * WING_LEN) for u in us]
    bottom = [(u * WING_LEN, -(0.015 + WING_BOTTOM * bulge(u)) * WING_LEN) for u in reversed(us[1:-1])]
    return top + bottom


# A leg relative to its hip (right side): a short black thigh, then a long
# thin shin sloping down and back, then a foot pointing back.
LEG_SHAPE = [(0.12, -0.07, 0.05), (0.2, -0.27, 0.3), (0.23, -0.3, 0.42)]
LEG_HIPS = [(-0.06, 1.2), (0.1, 1.8), (0.26, 1.2)]   # (front to back, length); middle leg 1.5 times the others


def leg(hip, length):
    hip = np.array(hip)
    pts = [hip] + [hip + np.array(p) * length for p in LEG_SHAPE]
    return kit.tube(pts, [0.032, 0.018, 0.014], sections=5)


def trumpet():
    """Snout: a thin stem that flares into a flat trumpet bell at the bottom."""
    profile = [(0, 0), (0.12, 0), (0.12, 0.025), (0.085, 0.055), (0.055, 0.11),
               (0.042, 0.2), (0.045, 0.34), (0, 0.34)]   # (radius, height)
    m = kit.trimesh.creation.revolve(profile, sections=14)
    m.apply_transform(kit.trimesh.transformations.rotation_matrix(-math.pi / 2, (1, 0, 0)))  # stand it up
    m.apply_transform(kit.trimesh.transformations.rotation_matrix(math.radians(-15), (1, 0, 0)))  # bell a bit forward
    m.apply_translation((0, -0.6, -0.5))
    return m


def build():
    body = kit.ellipsoid((0, 0, 0), BODY_R, rings=9, segments=14)
    snout = trumpet()
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
    legs = [leg((0.12, -0.28, z), length) for z, length in LEG_HIPS]
    legs = kit.trimesh.util.concatenate(legs + [kit.mirror_x(m) for m in legs])

    outline_2d = wing_outline()
    place = kit.frame(WING_DIR, (1.0, 0.3, -0.2))
    place[:3, 3] = HINGE
    wing_r = kit.flat_shape(outline_2d, 0.02)
    wing_r.apply_transform(place)
    rim_r = kit.ring_shape(outline_2d, 0.035, 0.03)
    rim_r.apply_transform(place)

    body_all = kit.trimesh.util.concatenate([body, snout])
    outline = kit.trimesh.util.concatenate([
        kit.outline_shell(body, OUTLINE), kit.outline_shell(eye_r, OUTLINE),
        kit.outline_shell(eye_l, OUTLINE), kit.outline_shell(snout, OUTLINE * 0.7)])
    parts = {
        "Body": body_all,
        "Eyes": kit.trimesh.util.concatenate([eye_r, eye_l]),
        "Black": kit.trimesh.util.concatenate([pupil_r, pupil_l, legs]),
        "Outline": outline,
        "WingR": wing_r, "WingL": kit.mirror_x(wing_r),
        "WingRimR": rim_r, "WingRimL": kit.mirror_x(rim_r),
    }

    scale = BODY_LENGTH / (2 * BODY_R[2])
    for m in parts.values():
        m.apply_scale(scale)
    hinge_r = HINGE * scale
    hinge_l = hinge_r * np.array([-1, 1, 1])
    extras = {
        "bodyLength": BODY_LENGTH,
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
