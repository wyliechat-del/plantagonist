"""Builds the Rain Cloud from Wylie's brief: six small puffy cloud blobs that
appear over the rain shadow, drift together as the shadow shrinks, and end
up as one big layered cloud (like the cartoon storm cloud reference), in
6f706f and a7abae with the black keyline.

Usage (from the repo root):
  python3 scripts/models/build_cloud.py models/creatures/RainCloud.glb

Sizes are in studs at game scale: the whole cloud is about 2 x cloudRadius
(Config Environment.Rain, 14) across, so it covers the rain spot.

Layout: three light blobs (a7abae) at the back, the middle one higher, and
three dark blobs (6f706f) in front, like the two layers in the reference.

Motion (Wylie): during the rain warning the six blobs pop up spread out over
the shadow, then come together as the shadow shrinks, ending as the full
cloud. In the JSON "moving" list with "onEvent": "rainWarning" as keyframes
([time 0..1, offset from the blob's place in the full cloud, scale]); the
game plays them over Environment.Rain.shadowSeconds. The blobs' spread
follows the shadow's radius (shadowStartRadius down to cloudRadius).

Parts:
  Blob1-6     the six cloud blobs (1-3 light at the back, 4-6 dark in front)
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
KEYLINE_W = 0.35             # studs (the cloud is seen from far away)
SHADOW_Y = -10              # preview only: where the shadow disc is drawn
SQUASH = 0.85                # puffs are a little flatter than round

LIGHT = (167, 171, 174, 255)   # a7abae
DARK = (111, 112, 111, 255)    # 6f706f
BLACK = (0, 0, 0, 255)

# Each blob: (place in the full cloud, light?, puffs as (x, y, z, radius)
# relative to that place). Front is -Z.
BLOBS = [
    ((-8.5, 3.0, 3.0), True, [(-3.0, 0, 0, 3.6), (1.2, 1.4, 0, 4.4), (4.5, -0.4, 0.5, 3.0)]),
    ((0.0, 6.5, 4.0), True, [(-3.4, -0.6, 0, 3.8), (0.4, 1.2, 0, 5.4), (4.2, -0.8, 0, 3.6)]),
    ((8.5, 3.5, 3.0), True, [(-4.0, 0, 0.5, 3.0), (-0.6, 1.0, 0, 4.2), (3.4, -0.6, 0, 3.4)]),
    ((-8.0, -0.5, -2.5), False, [(-3.6, -0.4, 0, 3.2), (0, 1.0, 0, 4.2), (3.6, 0, 0, 3.4)]),
    ((0.0, 0.5, -3.5), False, [(-3.8, 0, 0, 3.4), (0, 1.4, 0, 4.4), (3.8, -0.2, 0, 3.6)]),
    ((8.0, -0.5, -2.5), False, [(-3.4, 0, 0, 3.4), (0.2, 1.0, 0, 4.0), (3.8, -0.4, 0, 3.0)]),
]


def blob(place, puffs):
    spheres = [kit.ellipsoid(np.add(place, (x, y, z)), (r, r * SQUASH, r), rings=12, segments=18)
               for x, y, z, r in puffs]
    body = kit.trimesh.util.concatenate(spheres)
    rim = kit.trimesh.util.concatenate([kit.outline_shell(s, KEYLINE_W) for s in spheres])
    return body, rim


def keys(place, k):
    """Pop up spread out, then drift in with the shrinking shadow."""
    rng = np.random.default_rng(11 + k)
    flat = np.array([place[0], 0, place[2]])
    a = math.atan2(place[0], -place[2]) + rng.uniform(-0.2, 0.2)   # straight out from its place
    # Spread out over the shadow: the blobs sit about 70% of the way to its edge.
    far = np.array([math.sin(a), 0, -math.cos(a)]) * SHADOW_START * 0.6 - flat
    far += np.array([0, rng.uniform(-2, 3), 0])
    r = lambda v: [round(float(x), 2) for x in v]
    out = [[0.0, r(far), [0, 0, 0]],
           [0.08 + 0.02 * k, r(far), [1.15, 1.15, 1.15]],       # pop up, one after another
           [0.12 + 0.02 * k, r(far), [1, 1, 1]]]
    # Then in step with the shadow, which shrinks at a steady rate.
    for t in (0.4, 0.6, 0.8):
        shadow = SHADOW_START + (CLOUD_RADIUS - SHADOW_START) * t
        share = (shadow - CLOUD_RADIUS) / (SHADOW_START - CLOUD_RADIUS)
        out.append([t, r(far * share), [1, 1, 1]])
    out += [[0.92, [0, 0, 0], [1, 1, 1]], [1.0, [0, 0, 0], [1, 1, 1]]]
    return out


def build():
    parts, colours, moving = {}, {}, []
    for k, (place, light, puffs) in enumerate(BLOBS, 1):
        body, rim = blob(place, puffs)
        parts[f"Blob{k}"], parts[f"BlobRim{k}"] = body, rim
        colours[f"Blob{k}"], colours[f"BlobRim{k}"] = LIGHT if light else DARK, BLACK
        moving.append({"parts": [f"Blob{k}", f"BlobRim{k}"], "hinge": list(place),
                       "onEvent": "rainWarning", "keys": keys(place, k - 1)})
    # Preview only: the game's shadow disc, shrinking from SHADOW_START to
    # CLOUD_RADIUS, drawn just under the cloud so the timing is clear.
    shadow = kit.trimesh.creation.cylinder(radius=1, height=0.2, sections=48)
    shadow.apply_transform(kit.trimesh.transformations.rotation_matrix(math.pi / 2, (1, 0, 0)))
    shadow.apply_translation((0, SHADOW_Y, 0))
    parts["PreviewShadow"] = shadow
    colours["PreviewShadow"] = (10, 10, 30, 90)
    moving.append({"parts": ["PreviewShadow"], "hinge": [0, SHADOW_Y, 0], "previewOnly": True,
                   "keys": [[t, [0, 0, 0], [r, 1, r]] for t, r in
                            ((0, SHADOW_START), (0.5, (SHADOW_START + CLOUD_RADIUS) / 2), (1, CLOUD_RADIUS))]})
    extras = {"moving": moving, "eventSeconds": SHADOW_SECONDS, "motionFrames": 60,
              "previewOnly": ["PreviewShadow"],
              "motionView": {"azimuth": -25, "elevation": 32, "zoom": 2.5}}
    return parts, colours, extras


if __name__ == "__main__":
    parts, colours, extras = build()
    info = kit.export(sys.argv[1], parts, colours, extras)
    print("size", info["size"], "triangles", info["triangles"])
