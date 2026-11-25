"""Builds the Rain Cloud from Wylie's brief: six small puffy cloud blobs that
appear over the rain shadow, drift together as the shadow shrinks, and end
up as one big layered cloud (like the cartoon storm cloud reference), in
6f706f and a7abae with the black keyline.

Usage (from the repo root):
  python3 scripts/models/build_cloud.py models/creatures/RainCloud.glb

Sizes are in studs at game scale: the whole cloud is about 2 x cloudRadius
(Config Environment.Rain, 14) across, so it covers the rain spot.

Layout: see BLOBS; light (a7abae) and dark (6f706f) blobs alternate.

Motion (Wylie): during the rain warning the six blobs pop up spread out over
the shadow, then come together as the shadow shrinks, ending as the full
cloud. In the JSON "moving" list with "onEvent": "rainWarning" as keyframes
([time 0..1, offset from the blob's place in the full cloud, scale,
turn in degrees about up]); the
game plays them over Environment.Rain.shadowSeconds. When the rain ends
("onEvent": "rainEnd") each blob fades out and shrinks to half size over 1
second; the 5th value in those keys is opacity (1 solid, 0 gone), which
is 1 minus Roblox Transparency. The blobs' spread
follows the shadow's radius (shadowStartRadius down to cloudRadius).

Parts:
  Blob1-6     the six cloud blobs (odd light, even dark)
  BlobRim1-6  their black keylines (move with them)
  PreviewShadow  only for the preview pictures; the game has its own shadow
"""
import math
import sys

import numpy as np

import creature_kit as kit

CLOUD_RADIUS = 14            # studs, Environment.Rain.cloudRadius
SHADOW_START = 60            # studs, Environment.Rain.shadowStartRadius
SHADOW_SECONDS = 10          # Environment.Rain.shadowSeconds
END_SECONDS = 1              # Wylie: blobs shrink and fade out over 1 second when the rain ends
KEYLINE_W = 0.35             # studs (the cloud is seen from far away)
SHADOW_Y = -10              # preview only: where the shadow disc is drawn
SQUASH = 0.85                # puffs are a little flatter than round

LIGHT = (167, 171, 174, 255)   # a7abae
DARK = (111, 112, 111, 255)    # 6f706f
BLACK = (0, 0, 0, 255)

# Each blob: (place in the full cloud, light?, turn in the full cloud
# (degrees about up), where it pops up round the shadow (degrees, 0 is the
# front, 90 the right), how far it is turned while apart (degrees), puffs as
# (x, y, z, radius) along its length). Front is -Z.
# Wylie: colours alternate light, dark, light... round the ring they pop up
# in, and each points a different way while apart, then turns as it moves
# in. The full cloud is a clump with colours alternating front to back: a
# dark top at the back, light on each side, dark below them and a light
# blob low at the front.
BLOBS = [
    ((-2.5, -1.2, -4.5), True, -4, 0, 55,
     [(-4.0, 0, 0, 3.2), (0, 1.0, 0, 4.2), (4.0, -0.2, 0, 3.4)]),
    ((7.0, 0.6, -1.5), False, 10, 60, -70,
     [(-3.6, -0.2, 0, 3.4), (0, 1.0, 0, 4.0), (3.6, 0, 0, 3.0)]),
    ((6.8, 4.2, 1.5), True, -8, 120, 40,
     [(-4.2, 0, 0, 3.4), (-0.4, 1.2, 0, 4.4), (3.6, -0.3, 0, 3.4)]),
    ((1.5, 7.2, 4.5), False, 6, 180, -50,
     [(-4.4, -0.6, 0, 3.8), (0, 1.0, 0, 5.2), (4.4, -0.6, 0, 3.8)]),
    ((-6.2, 4.6, 1.5), True, 12, 240, 75,
     [(-3.8, -0.3, 0, 3.4), (0.2, 1.2, 0, 4.4), (4.0, 0, 0, 3.4)]),
    ((-8.0, 0.8, -1.0), False, -10, 300, -35,
     [(-3.6, 0, 0, 3.2), (0, 1.0, 0, 4.0), (3.8, -0.3, 0, 3.4)]),
]


def blob(place, turn, puffs):
    spin = kit.trimesh.transformations.rotation_matrix(math.radians(turn), (0, 1, 0))[:3, :3]
    spheres = [kit.ellipsoid(np.add(place, spin @ np.array((x, y, z))), (r, r * SQUASH, r), rings=12, segments=18)
               for x, y, z, r in puffs]
    body = kit.trimesh.util.concatenate(spheres)
    rim = kit.trimesh.util.concatenate([kit.outline_shell(s, KEYLINE_W) for s in spheres])
    return body, rim


def keys(place, k, around, apart_turn):
    """Pop up spread out, then drift in with the shrinking shadow, turning
    into place as they come. Each key: [time, offset, scale, turn degrees]."""
    rng = np.random.default_rng(11 + k)
    flat = np.array([place[0], 0, place[2]])
    a = math.radians(around)
    # Spread out over the shadow: the blobs sit about 70% of the way to its edge.
    far = np.array([math.sin(a), 0, -math.cos(a)]) * SHADOW_START * 0.6 - flat
    far += np.array([0, rng.uniform(-2, 3), 0])
    r = lambda v: [round(float(x), 2) for x in v]
    out = [[0.0, r(far), [0, 0, 0], apart_turn],
           [0.08 + 0.02 * k, r(far), [1.15, 1.15, 1.15], apart_turn],   # pop up, one after another
           [0.12 + 0.02 * k, r(far), [1, 1, 1], apart_turn]]
    # Then in step with the shadow, which shrinks at a steady rate.
    for t in (0.4, 0.6, 0.8):
        shadow = SHADOW_START + (CLOUD_RADIUS - SHADOW_START) * t
        share = (shadow - CLOUD_RADIUS) / (SHADOW_START - CLOUD_RADIUS)
        out.append([t, r(far * share), [1, 1, 1], round(apart_turn * share, 1)])
    out += [[0.92, [0, 0, 0], [1, 1, 1], 0], [1.0, [0, 0, 0], [1, 1, 1], 0]]
    return out


def build():
    parts, colours, moving = {}, {}, []
    for k, (place, light, turn, around, apart_turn, puffs) in enumerate(BLOBS, 1):
        body, rim = blob(place, turn, puffs)
        parts[f"Blob{k}"], parts[f"BlobRim{k}"] = body, rim
        colours[f"Blob{k}"], colours[f"BlobRim{k}"] = LIGHT if light else DARK, BLACK
        moving.append({"parts": [f"Blob{k}", f"BlobRim{k}"], "hinge": list(place),
                       "onEvent": "rainWarning", "keys": keys(place, k - 1, around, apart_turn)})
        # Wylie: when the rain ends each blob fades out and shrinks to half
        # size over 1 second (a little after one another); the fade is
        # quicker so it shows.
        start = round(0.04 * (k - 1), 2)
        moving.append({"parts": [f"Blob{k}", f"BlobRim{k}"], "hinge": list(place), "onEvent": "rainEnd",
                       "keys": [[0, [0, 0, 0], [1, 1, 1], 0, 1], [start, [0, 0, 0], [1, 1, 1], 0, 1],
                                [start + 0.45, [0, 0, 0], [0.75, 0.75, 0.75], 0, 0.25],
                                [0.85, [0, 0, 0], [0.55, 0.55, 0.55], 0, 0],
                                [1, [0, 0, 0], [0.5, 0.5, 0.5], 0, 0]]})
    # Preview only: the game's shadow disc, shrinking from SHADOW_START to
    # CLOUD_RADIUS, drawn just under the cloud so the timing is clear.
    shadow = kit.trimesh.creation.cylinder(radius=1, height=0.2, sections=48)
    shadow.apply_transform(kit.trimesh.transformations.rotation_matrix(math.pi / 2, (1, 0, 0)))
    shadow.apply_translation((0, SHADOW_Y, 0))
    parts["PreviewShadow"] = shadow
    colours["PreviewShadow"] = (10, 10, 30, 90)
    moving.append({"parts": ["PreviewShadow"], "hinge": [0, SHADOW_Y, 0], "previewOnly": True,
                   "onEvent": "rainWarning",
                   "keys": [[t, [0, 0, 0], [r, 1, r]] for t, r in
                            ((0, SHADOW_START), (0.5, (SHADOW_START + CLOUD_RADIUS) / 2), (1, CLOUD_RADIUS))]})
    extras = {"moving": moving, "eventSeconds": {"rainWarning": SHADOW_SECONDS, "rainEnd": END_SECONDS},
              "motionFrames": 60, "eventFrames": {"rainEnd": 25},
              "eventViews": {"rainEnd": {"azimuth": -25, "elevation": 20}},
              "previewOnly": ["PreviewShadow"],
              "motionView": {"azimuth": -25, "elevation": 32, "zoom": 2.5}}
    return parts, colours, extras


if __name__ == "__main__":
    parts, colours, extras = build()
    info = kit.export(sys.argv[1], parts, colours, extras)
    print("size", info["size"], "triangles", info["triangles"])
