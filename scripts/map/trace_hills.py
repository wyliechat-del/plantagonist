"""
Traces Wylie's Hills quarter picture (models/maps/hills.png) into polygons
for the game: rises, tunnels, the cave room, ramps and the bottom left hill.
Writes src/shared/Config/HillsShape.luau (generated; don't edit by hand).

The picture covers the Hills quarter exactly: left edge X = 0, right edge
X = 350, top edge Z = -350, bottom edge Z = 0.

Colours: ground (148,140,105), First Rise (123,115,84), Second Rise
(88,83,62), Third Rise (55,51,38), tunnel (43,43,43), ramp (255,255,255).

Usage: python3 scripts/map/trace_hills.py   (needs opencv-python-headless)
"""

import math
import os

import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "models", "maps", "hills.png")
OUT = os.path.join(ROOT, "src", "shared", "Config", "HillsShape.luau")

SIZE = 350  # studs across the quarter
CELL = 1  # studs per grid cell
SIMPLIFY = 1.5  # studs: how closely the polygons follow the picture

COLOURS = {
    "ground": (148, 140, 105),
    "rise1": (123, 115, 84),
    "rise2": (88, 83, 62),
    "rise3": (55, 51, 38),
    "tunnel": (43, 43, 43),
    "ramp": (255, 255, 255),
}
LEVEL = {"ground": 0, "rise1": 1, "rise2": 2, "rise3": 3, "tunnel": 9, "ramp": 8}
# The bottom left hill is its own shape (a ridge over a tunnel); this point
# (studs) is inside it.
HILL_POINT = (100, -100)
# Its outline, measured from the picture: middle, length, width and the
# direction of its length (the tunnel runs along it).
HILL = {"x": 100.4, "z": -100.4, "length": 84, "width": 46, "dx": 0.625, "dz": 0.7806}


def to_studs(px, py, scale):
    return px * scale, -SIZE + py * scale


def main():
    image = cv2.cvtColor(cv2.imread(SOURCE), cv2.COLOR_BGR2RGB).astype(np.int32)
    height, width, _ = image.shape
    # Nearest palette colour per pixel; anything else (labels, the field,
    # the border) counts as ground.
    names = list(COLOURS)
    palette = np.array([COLOURS[n] for n in names])
    distance = ((image[:, :, None, :] - palette[None, None, :, :]) ** 2).sum(axis=3)
    nearest = distance.argmin(axis=2)
    close = distance.min(axis=2) < 300
    labels = np.where(close, np.array([LEVEL[n] for n in names])[nearest], 0)

    cells = SIZE // CELL
    grid = cv2.resize(labels.astype(np.uint8), (cells, cells), interpolation=cv2.INTER_NEAREST)
    # Clean up stray pixels from the picture's soft edges.
    grid = cv2.medianBlur(grid, 5)
    # The picture's dark border along the top isn't a tunnel.
    grid[:3, :] = np.where(grid[:3, :] == 9, 0, grid[:3, :])

    # What each tunnel or ramp cell would be without it: the nearest plain layer.
    plain = np.isin(grid, [0, 1, 2, 3])
    base = grid.copy()
    _, index = cv2.distanceTransformWithLabels(
        (~plain).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL
    )
    ys, xs = np.nonzero(plain)
    lookup = np.zeros(index.max() + 1, dtype=np.uint8)
    lookup[index[ys, xs]] = grid[ys, xs]
    base = np.where(plain, grid, lookup[index])
    # Ramps sit on the ground in front of the rise.
    base = np.where(grid == 8, 0, base)

    scale = SIZE / cells

    def polygons(mask, min_area=20):
        mask = mask.astype(np.uint8)
        contours, hierarchy = cv2.findContours(mask, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
        result, holes = [], 0
        for i, contour in enumerate(contours):
            if hierarchy[0][i][3] != -1:
                if cv2.contourArea(contour) * scale * scale >= min_area:
                    holes += 1
                continue
            if cv2.contourArea(contour) * scale * scale < min_area:
                continue
            simple = cv2.approxPolyDP(contour, SIMPLIFY / scale, True)
            points = []
            for p in simple[:, 0, :]:
                x, z = to_studs(p[0] + 0.5, p[1] + 0.5, scale)
                points.append((round(x, 1), round(z, 1)))
            if len(points) >= 3:
                result.append(points)
        return result, holes

    # The bottom left hill: the rise 1 blob containing HILL_POINT.
    hx = int(HILL_POINT[0] / scale)
    hy = int((HILL_POINT[1] + SIZE) / scale)
    count, components = cv2.connectedComponents((base >= 1).astype(np.uint8))
    hill_id = components[hy, hx]
    hill_mask = components == hill_id
    hill_area = cv2.dilate(hill_mask.astype(np.uint8), np.ones((15, 15), np.uint8)).astype(bool)
    rises = {}
    report = []
    for level in (1, 2, 3):
        mask = (base >= level) & ~hill_area
        polys, holes = polygons(mask)
        rises[level] = polys
        report.append(f"rise{level}: {len(polys)} polygons, {holes} holes")

    hill = dict(HILL)
    tunnel_mask = grid == 9
    tunnel_mask_no_hill = tunnel_mask & ~hill_area
    tunnels, _ = polygons(tunnel_mask_no_hill)
    # Cave room: the tunnel blob with its thin arms opened away.
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (int(26 / scale), int(26 / scale)))
    room_mask = cv2.morphologyEx(tunnel_mask_no_hill.astype(np.uint8), cv2.MORPH_OPEN, kernel)
    rooms, _ = polygons(room_mask, min_area=200)

    # Ramps: each white blob as a rectangle, high end against the rise.
    ramps = []
    ramp_mask = (grid == 8).astype(np.uint8)
    contours, _ = cv2.findContours(ramp_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    for contour in contours:
        if cv2.contourArea(contour) * scale * scale < 50:
            continue
        box = cv2.boxPoints(cv2.minAreaRect(contour))
        # Score each side by how much rise 1 lies just outside it.
        best, best_score = None, -1
        centre = box.mean(axis=0)
        for i in range(4):
            p, q = box[i], box[(i + 1) % 4]
            mid = (p + q) / 2
            out = mid + (mid - centre) / np.linalg.norm(mid - centre) * (4 / scale)
            score = 0
            for t in np.linspace(0.1, 0.9, 9):
                s = p + (q - p) * t + (out - mid)
                sx, sy = int(s[0]), int(s[1])
                if 0 <= sx < cells and 0 <= sy < cells and base[sy, sx] >= 1 and grid[sy, sx] != 8:
                    score += 1
            if score > best_score:
                best, best_score = i, score
        p, q = box[best], box[(best + 1) % 4]
        r, s = box[(best + 2) % 4], box[(best + 3) % 4]
        # High edge p-q, low edge r-s.
        ramps.append({
            "high": [to_studs(p[0], p[1], scale), to_studs(q[0], q[1], scale)],
            "low": [to_studs(s[0], s[1], scale), to_studs(r[0], r[1], scale)],
        })

    def lua_points(points, indent):
        pad = "\t" * indent
        lines = [f"{pad}points({{"]
        for x, z in points:
            lines.append(f"{pad}\t{{ {x:g}, {z:g} }},")
        lines.append(f"{pad}}}),")
        return lines

    out = [
        "--[[",
        "\tGENERATED by scripts/map/trace_hills.py from models/maps/hills.png.",
        "\tDon't edit by hand: change the picture and run the script again.",
        "\tPolygons are { x, z } corners in studs. Heights and looks are in",
        "\t`Config/Map.luau` (Map.Hills).",
        "]]",
        "",
        "local function points(list: { { number } }): { { number } }",
        "\tfor _, point in list do",
        "\t\ttable.freeze(point)",
        "\tend",
        "\treturn table.freeze(list)",
        "end",
        "",
        "local function list(items: { any }): { any }",
        "\treturn table.freeze(items)",
        "end",
        "",
        "local HillsShape = {}",
        "",
        "-- Outlines of everything at or above each rise (index 1 to 3).",
        "HillsShape.rises = list({",
    ]
    for level in (1, 2, 3):
        out.append("\tlist({")
        for poly in rises[level]:
            out += lua_points(poly, 2)
        out.append("\t}),")
    out.append("})")
    out.append("")
    out.append("-- Tunnels at ground level (the cave included).")
    out.append("HillsShape.tunnels = list({")
    for poly in tunnels:
        out += lua_points(poly, 1)
    out.append("})")
    out.append("")
    out.append("-- The cave room: the wide middle of the big tunnel.")
    out.append("HillsShape.caveRooms = list({")
    for poly in rooms:
        out += lua_points(poly, 1)
    out.append("})")
    out.append("")
    out.append("-- Ramps up to the First Rise: the high edge's two corners, then the")
    out.append("-- low edge's (same order).")
    out.append("HillsShape.ramps = list({")
    for ramp in ramps:
        (a1, a2), (b1, b2) = ramp["high"], ramp["low"]
        out.append("\tlist({")
        out.append(f"\t\thigh = points({{ {{ {a1[0]:.1f}, {a1[1]:.1f} }}, {{ {a2[0]:.1f}, {a2[1]:.1f} }} }}),")
        out.append(f"\t\tlow = points({{ {{ {b1[0]:.1f}, {b1[1]:.1f} }}, {{ {b2[0]:.1f}, {b2[1]:.1f} }} }}),")
        out.append("\t}),")
    out.append("})")
    out.append("")
    out.append("-- The bottom left hill: a ridge with a tunnel along it. Middle, size")
    out.append("-- and the direction of its length.")
    out.append("HillsShape.ridge = table.freeze({")
    for key in ("x", "z", "length", "width", "dx", "dz"):
        out.append(f"\t{key} = {hill[key]:g},")
    out.append("})")
    out.append("")
    out.append("return table.freeze(HillsShape)")
    with open(OUT, "w") as f:
        f.write("\n".join(out) + "\n")
    print("\n".join(report))
    print("tunnels", len(tunnels), "rooms", len(rooms), "ramps", len(ramps), "hill", hill)


if __name__ == "__main__":
    main()
