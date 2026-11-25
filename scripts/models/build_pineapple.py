"""Builds the Pineapple (the Yellow Special Fruit) from Wylie's drawing
(models/creatures/art/pineapple-drawing.png): a yellow egg-shaped body with
an orange criss-cross pattern, a spiky green crown, the same happy face as
the apple and a black keyline.

Usage (from the repo root):
  python3 scripts/models/build_pineapple.py models/creatures/Pineapple.glb

Measured from the drawing in pixels (as shown at 1932 px across): the body
is 675 px wide and 750 px tall, its bottom at y 1530, its middle at x 1002.
Heights in the profile are pixels up from the bottom. The body is HEIGHT
studs tall, like the other fruits.

Motion (Wylie): the same bounce as the other fruits, and the crown spikes
spread out a little as it lands.

Parts:
  Body      yellow body
  Lattice   orange criss-cross lines on the body
  Crown     dark green spikes (move)
  CrownLight light green spikes, every other one in each ring (move)
  Eyes      white of the eyes
  Outline   black keyline round the body and eyes, plus pupils, eye rims and smile
  CrownRim  black keyline round each spike (moves with them)
  OuterSpike1-5, OuterSpikeRim1-5  the outer ring, one part per spike so each
           tips out about its own base on landing
"""
import math
import sys

import numpy as np

import creature_kit as kit

HEIGHT = 2.0                 # studs, body only
BOUNCE_HEIGHT = 0.3          # studs, how high each hop goes
BOUNCE_SQUASH = 0.8          # height on landing, as a share of full height
SPREAD_WIDE = 1.25           # crown width at the deepest squish, as a share
SPREAD_SHORT = 0.9           # crown height at the deepest squish, as a share

YELLOW = (244, 187, 71, 255)   # colours picked from the drawing
ORANGE = (250, 149, 30, 255)
GREEN = (93, 124, 44, 255)
LIGHT_GREEN = (140, 198, 63, 255)   # Wylie: 8cc63f on every other spike
WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)

CENTRE_X, BOTTOM_Y = 1002, 1530
PROFILE = [(0, 0), (90, 6), (148, 30), (215, 70), (268, 130), (305, 200), (323, 280),
           (335, 400), (328, 470), (303, 530), (270, 585), (238, 630), (200, 675),
           (168, 710), (120, 740), (60, 749), (0, 751)]
PX = HEIGHT / 750            # studs per drawing pixel
KEYLINE_W = 0.018 * 2.0      # same keyline as the other fruits

LATTICE_LINES = 10           # lines each way round the body
LATTICE_R = 10               # px, half the width of a lattice line

FACE_UP = 70                 # Wylie: face a little higher than in the drawing
EYES = [((864, 1173 - FACE_UP), 108), ((1139, 1173 - FACE_UP), 108)]
PUPILS = [((863, 1178 - FACE_UP), 52), ((1139, 1178 - FACE_UP), 52)]
SMILE = [(x, y - FACE_UP) for x, y in
         [(912, 1357), (950, 1378), (980, 1382), (1020, 1370), (1050, 1350), (1077, 1325)]]
SMILE_TICK = [(x, y - FACE_UP) for x, y in
              [(1066, 1280), (1068, 1305), (1080, 1325), (1100, 1337), (1122, 1340)]]
FACE_LIFT = 12               # px off the skin, above the lattice lines

# Crown (redrawn from Wylie's references): curved, pointed leaves that all
# grow out of one spot on top. Short ones curl out low, tall ones stand up
# in the middle. Each leaf has a channel down its middle.
# (count, length px, widest px, start lean degrees, extra bend to the tip, turn degrees)
# The first ring is the outer one; its leaves tip out OUTER_TURN degrees
# as the fruit lands.
CROWN = [(6, 310, 165, 38, 22, 0), (5, 430, 155, 24, 18, 36), (3, 520, 135, 7, 10, 60)]
OUTER_TURN = 22
LEAF_FOLD = 0.6              # how deep the channel is, as a share of the half width
LEAF_THICK = 10              # px
CROWN_BASE = 735             # px up from the bottom, a little inside the top


def radius_at(h_studs):
    return float(np.interp(h_studs / PX, [p[1] for p in PROFILE], [p[0] for p in PROFILE])) * PX


on_face = kit.front_mapper(radius_at, CENTRE_X, BOTTOM_Y, PX)


def leaf_width(t, widest):
    """Narrow at the base, widest a third of the way up, pointed tip."""
    if t < 0.33:
        return widest * (0.45 + 0.55 * math.sin(math.pi / 2 * t / 0.33))
    return max(widest * ((1 - t) / 0.67) ** 0.85, 2)


def crown():
    """Returns the inner leaves (dark, light, keylines) and the outer leaves
    as a list of (dark or light, leaf, keyline, hinge, axis): each outer leaf
    is its own part so it can tip out about its base."""
    leaves, light, rims, outer = [], [], [], []
    n = 0                    # counts leaves across all rings, so exactly half are light
    y_axis = np.array([0.0, 1.0, 0.0])
    for ring_no, (count, length, widest, lean, bend, turn) in enumerate(CROWN):
        for i in range(count):
            phi = math.radians(turn + 360 * i / count)
            out = np.array([math.sin(phi), 0, -math.cos(phi)])     # phi 0 is the front
            side = np.array([math.cos(phi), 0, math.sin(phi)])
            base = np.array([0, CROWN_BASE * PX, 0]) + out * 8 * PX
            spine, across, inner, widths = [], [], [], []
            p = base.copy()
            steps = 14
            for k in range(steps + 1):
                t = k / steps
                a = math.radians(lean + bend * t * t)              # bends more towards the tip
                d = math.sin(a) * out + math.cos(a) * y_axis
                spine.append(p.copy())
                across.append(side)
                inner.append(-math.cos(a) * out + math.sin(a) * y_axis)
                widths.append(leaf_width(t, widest) * PX)
                p = p + d * length / steps * PX
            m = kit.blade(spine, across, inner, widths, LEAF_FOLD, LEAF_THICK * PX)
            rim = kit.outline_shell(m, KEYLINE_W * 0.6)
            if ring_no == 0:
                # Turning about -side tips the leaf outward.
                outer.append((n % 2, m, rim, base, -side))
            else:
                (light if n % 2 else leaves).append(m)
                rims.append(rim)
            n += 1
    cat = kit.trimesh.util.concatenate
    return cat(leaves), cat(light), cat(rims), outer


def lattice():
    """Orange lines spiralling round the body both ways, at 45 degrees
    where the body is widest, like the criss-cross in the drawing."""
    widest = max(r for r, _ in PROFILE)
    lines = []
    for direction in (1, -1):
        for k in range(LATTICE_LINES):
            phi0 = 2 * math.pi * k / LATTICE_LINES
            pts, outs = [], []
            for h in np.linspace(18, 728, 40):
                r = float(np.interp(h, [p[1] for p in PROFILE], [p[0] for p in PROFILE]))
                phi = phi0 + direction * (h - 400) / widest
                out = np.array([math.sin(phi), 0, -math.cos(phi)])
                pts.append((out * (r + 3) + np.array([0, h, 0])) * PX)
                outs.append(out)
            lines.append(ribbon(pts, outs, LATTICE_R * PX))
    return kit.trimesh.util.concatenate(lines)


def ribbon(pts, outs, half):
    """A flat band along points on the skin, facing out."""
    verts, faces = [], []
    for i, (p, out) in enumerate(zip(pts, outs)):
        d = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
        across = np.cross(d, out)
        across /= np.linalg.norm(across)
        verts += [p - across * half, p + across * half]
    for i in range(len(pts) - 1):
        a, b, c, e = 2 * i, 2 * i + 1, 2 * i + 2, 2 * i + 3
        faces += [[a, b, e], [a, e, c]]
    m = kit.trimesh.Trimesh(np.array(verts), np.array(faces), process=False)
    if np.dot(m.face_normals[0], outs[0]) < 0:
        m.invert()
    return m


def build():
    body = kit.lathe([(r * PX, h * PX) for r, h in PROFILE], sections=32)
    spikes, light_spikes, spike_rims, outer = crown()

    whites, blacks = [], []
    rim_px = KEYLINE_W / PX
    for c, r in EYES:
        eye = kit.circle(c, r)
        whites.append(kit.bend_onto(on_face, eye, FACE_LIFT, 4))
        blacks.append(kit.bend_onto(on_face, eye, FACE_LIFT + 3, 4, ring_px=rim_px))
    for c, r in PUPILS:
        blacks.append(kit.bend_onto(on_face, kit.circle(c, r, 32), FACE_LIFT + 2, 4))
    for line in (SMILE, SMILE_TICK):
        blacks.append(kit.tube([on_face(x, y, FACE_LIFT) for x, y in line], KEYLINE_W * 0.35, sections=6))

    parts = {
        "Body": body,
        "Lattice": lattice(),
        "Crown": spikes,
        "CrownLight": light_spikes,
        "Eyes": kit.trimesh.util.concatenate(whites),
        "Outline": kit.trimesh.util.concatenate([kit.outline_shell(body, KEYLINE_W)] + blacks),
        "CrownRim": spike_rims,
    }
    colours = {"Body": YELLOW, "Lattice": ORANGE, "Crown": GREEN, "CrownLight": LIGHT_GREEN, "Eyes": WHITE,
               "Outline": BLACK, "CrownRim": BLACK}
    outer_movers = []
    for k, (is_light, m, rim, hinge, axis) in enumerate(outer, 1):
        parts[f"OuterSpike{k}"], parts[f"OuterSpikeRim{k}"] = m, rim
        colours[f"OuterSpike{k}"], colours[f"OuterSpikeRim{k}"] = LIGHT_GREEN if is_light else GREEN, BLACK
        outer_movers.append({"parts": [f"OuterSpike{k}", f"OuterSpikeRim{k}"],
                             "hinge": [round(float(v), 3) for v in hinge], "axis": [round(float(v), 3) for v in axis],
                             "cycles": 1, "spread": {"wide": 1, "short": 1, "turn": OUTER_TURN, "squashShare": 0.3}})
    extras = {
        "height": HEIGHT,
        "family": "Special",
        "moving": [
            # Same bounce as the other fruits.
            {"parts": "all", "hinge": [0, 0, 0], "cycles": 1,
             "bounce": {"height": BOUNCE_HEIGHT, "squash": BOUNCE_SQUASH, "squashShare": 0.3}},
            # Crown widens and shortens about its base while the body squishes,
            # so the spikes fan out.
            {"parts": ["Crown", "CrownLight", "CrownRim"], "hinge": [0, round(CROWN_BASE * PX, 3), 0], "cycles": 1,
             "spread": {"wide": SPREAD_WIDE, "short": SPREAD_SHORT, "squashShare": 0.3}},
            # Each outer spike tips out OUTER_TURN degrees about its base at the same time.
        ] + outer_movers,
        "motionFrames": 30,
        "motionView": {"azimuth": 0, "elevation": 10},
    }
    return parts, colours, extras


if __name__ == "__main__":
    parts, colours, extras = build()
    info = kit.export(sys.argv[1], parts, colours, extras, flat=tuple(n for n in parts if ("Spike" in n or n.startswith("Crown")) and "Rim" not in n))
    print("size", info["size"], "triangles", info["triangles"])
    for name, p in info["parts"].items():
        print(f"  {name}: {p['triangles']} triangles")
