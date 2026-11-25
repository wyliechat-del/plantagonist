"""Builds the Orange (the Strangle family's fruit) from the Red Apple, with
the changes Wylie asked for: colours from the orange drawing
(models/creatures/art/orange-strangle-drawing.png), the leaf on the other
side of the stem, and a rounder top (the flat area round the stem cut to a
quarter of the apple's).

Usage (from the repo root):
  python3 scripts/models/build_orange.py models/creatures/OrangeStrangle.glb

Same face, bounce and leaf flap as the apple (see build_apple.py).
"""
import sys

import build_apple as base
import creature_kit as kit

ORANGE = (241, 90, 36, 255)     # picked from the drawing
GREEN = (61, 135, 68, 255)      # leaf and stem in the drawing

# The apple's profile up to its shoulder, then a rounder dome: the flat
# top was about 200 px across each side of the stem, now about 50, with a
# small dip for the stem.
base.PROFILE = base.PROFILE[:11] + [(290, 578), (250, 622), (200, 658), (150, 684), (100, 701),
                                    (55, 708), (35, 702), (18, 690), (0, 684)]
base.TOP_INDEX = 16                                   # (55, 708), the highest point
STEM_X = 975
base.STEM = [(975, 1375 - 684), (978, 640), (985, 600), (995, 565)]
# The apple's leaf mirrored onto the other side of the stem, joined a little higher.
base.LEAF = [(2 * STEM_X - x, y - 30) for x, y in base.LEAF]
base.RIM_LINE = (60, 707, 130)


def build():
    parts, colours, extras = base.build()
    colours.update({"Apple": ORANGE, "Stem": GREEN, "Leaf": GREEN})
    parts["Orange"] = parts.pop("Apple")
    colours["Orange"] = colours.pop("Apple")
    extras["family"] = "Strangle"
    # The leaf now points the other way, so the flap's direction flips too
    # (still down at landing, up at the top of the hop).
    leaf = extras["moving"][1]
    leaf["from"], leaf["to"] = -leaf["from"], -leaf["to"]
    return parts, colours, extras


if __name__ == "__main__":
    parts, colours, extras = build()
    info = kit.export(sys.argv[1], parts, colours, extras, flat=("Leaf",))
    print("size", info["size"], "triangles", info["triangles"])
