"""Shared building blocks for creature models (fly first, more to follow).

A creature script builds named parts from these shapes and calls export().
Each part becomes one MeshPart in Studio, so give every colour its own part,
and keep anything that moves (wings, tails) as its own part too.

Axes match Roblox: +Y up, -Z is the front (where the creature looks).
Build one side at +X and copy it to the other side with mirror_x().
1 unit = 1 stud.

See transparency: Roblox ignores see-through pixels in imported textures, so
a see-through part is exported as a plain colour and the game sets the
part's Transparency (the alpha below is only for the preview renders).
"""
import json
import math

import numpy as np
import trimesh

OUTLINE_COLOUR = (0, 0, 0, 255)


def ellipsoid(centre, radii, rings=8, segments=14):
    m = trimesh.creation.uv_sphere(radius=1.0, count=[rings, segments])
    m.apply_scale(radii)
    m.apply_translation(centre)
    return m


def lathe(profile, sections=20):
    """Round shape spun from a side profile: a list of (radius, height)
    points from bottom to top. Stands upright along +Y."""
    m = trimesh.creation.revolve(profile, sections=sections)
    m.apply_transform(trimesh.transformations.rotation_matrix(-math.pi / 2, (1, 0, 0)))
    return m


def tube(points, radius, sections=6, joints=True):
    """Thin round tube along a list of points (legs, antennae)."""
    parts = []
    pts = [np.asarray(p, float) for p in points]
    radii = radius if isinstance(radius, (list, tuple)) else [radius] * (len(pts) - 1)
    for a, b, r in zip(pts, pts[1:], radii):
        parts.append(trimesh.creation.cylinder(radius=r, segment=[a, b], sections=sections))
    if joints:
        for p, r in zip(pts[1:-1], radii[1:]):
            parts.append(ellipsoid(p, (r, r, r), rings=3, segments=sections))
    return trimesh.util.concatenate(parts)


def flat_shape(outline_2d, thickness):
    """Extrude a 2D outline (list of (u, v), any simple shape, dents allowed)
    into a thin slab centred on z = 0. Needs `pip install mapbox_earcut networkx`."""
    import mapbox_earcut as earcut
    pts = np.asarray(outline_2d, float)
    n = len(pts)
    h = thickness / 2
    tris = np.asarray(earcut.triangulate_float64(pts, np.array([n], dtype=np.uint32))).reshape(-1, 3)
    verts = np.vstack([np.c_[pts, np.full(n, h)], np.c_[pts, np.full(n, -h)]])
    faces = [tris, tris[:, ::-1] + n]
    side = []
    for i in range(n):
        j = (i + 1) % n
        side += [[i, i + n, j + n], [i, j + n, j]]
    m = trimesh.Trimesh(verts, np.vstack(faces + [np.array(side)]), process=False)
    m.fix_normals()
    return m


def ring_shape(outline_2d, width, thickness):
    """A flat band just inside an outline (a black rim round a wing)."""
    pts = np.asarray(outline_2d, float)
    # Move each point inward along the outline's own normal, so the band
    # keeps an even width round dents and lobes too.
    area = np.sum(pts[:, 0] * np.roll(pts[:, 1], -1) - np.roll(pts[:, 0], -1) * pts[:, 1])
    d = np.roll(pts, -1, axis=0) - np.roll(pts, 1, axis=0)
    inward = np.c_[-d[:, 1], d[:, 0]] * (1 if area > 0 else -1)
    inward /= np.linalg.norm(inward, axis=1, keepdims=True)
    inner = pts + inward * width
    n = len(pts)
    h = thickness / 2
    verts = np.vstack([np.c_[pts, np.full(n, h)], np.c_[inner, np.full(n, h)],
                       np.c_[pts, np.full(n, -h)], np.c_[inner, np.full(n, -h)]])
    faces = []
    for i in range(n):
        j = (i + 1) % n
        o, ii, ob, ib = 0, n, 2 * n, 3 * n
        faces += [[o + i, o + j, ii + j], [o + i, ii + j, ii + i]]          # top
        faces += [[ob + i, ib + j, ob + j], [ob + i, ib + i, ib + j]]        # bottom
        faces += [[o + i, ob + i, ob + j], [o + i, ob + j, o + j]]           # outer edge
        faces += [[ii + i, ii + j, ib + j], [ii + i, ib + j, ib + i]]        # inner edge
    m = trimesh.Trimesh(verts, np.array(faces), process=False)
    m.fix_normals()
    return m


def blade(spine, across, inner, widths, fold, thickness):
    """A curved leaf with a channel down its middle (like a pineapple leaf),
    as a closed thin solid. spine: points from base to tip; across: unit
    vector across the leaf at each point; inner: unit vector the leaf's
    inside faces at each point; widths: full width at each point. The edges
    rise `fold` times the half width towards `inner`, so the leaf never
    looks like a line when seen edge on."""
    n = len(spine)
    top = []
    for p, a, i, w in zip(spine, across, inner, widths):
        h = w / 2
        top += [p - a * h + i * fold * h, p, p + a * h + i * fold * h]
    top = np.array(top)
    bottom = top - np.repeat(np.asarray(inner), 3, axis=0) * thickness
    verts = np.vstack([top, bottom])
    b = 3 * n
    faces = []
    for k in range(n - 1):
        for j in range(2):
            a0, a1, c0, c1 = 3 * k + j, 3 * k + j + 1, 3 * (k + 1) + j, 3 * (k + 1) + j + 1
            faces += [[a0, c0, c1], [a0, c1, a1], [b + a0, b + c1, b + c0], [b + a0, b + a1, b + c1]]
        for e in (0, 2):                                   # the two long edges
            a0, c0 = 3 * k + e, 3 * (k + 1) + e
            faces += [[a0, b + a0, b + c0], [a0, b + c0, c0]]
    for k in (0, n - 1):                                   # base and tip ends
        for j in range(2):
            a0, a1 = 3 * k + j, 3 * k + j + 1
            faces += [[a0, a1, b + a1], [a0, b + a1, b + a0]]
    m = trimesh.Trimesh(verts, np.array(faces), process=False)
    m.fix_normals()
    return m


def sweep(points, widths, heights, sections=12, up=(0, 1, 0)):
    """A smooth tube along a list of points with an oval cross-section
    (`widths` across, `heights` up, per point), closed at both ends. Unlike
    tube(), it is one smooth piece, so it bends without lumps."""
    pts = np.asarray(points, float)
    n = len(pts)
    up = np.asarray(up, float)
    rings = []
    for k in range(n):
        t = pts[min(k + 1, n - 1)] - pts[max(k - 1, 0)]
        t /= np.linalg.norm(t)
        side = np.cross(t, up)
        side /= np.linalg.norm(side)
        lift = np.cross(side, t)
        for j in range(sections):
            a = 2 * math.pi * j / sections
            rings.append(pts[k] + side * widths[k] * math.cos(a) + lift * heights[k] * math.sin(a))
    verts = np.vstack([np.array(rings), pts[0], pts[-1]])
    faces = []
    for k in range(n - 1):
        for j in range(sections):
            a, b = k * sections + j, k * sections + (j + 1) % sections
            faces += [[a, b, b + sections], [a, b + sections, a + sections]]
    first, last = n * sections, n * sections + 1
    for j in range(sections):
        faces.append([first, (j + 1) % sections, j])
        faces.append([last, (n - 1) * sections + j, (n - 1) * sections + (j + 1) % sections])
    m = trimesh.Trimesh(verts, np.array(faces), process=False)
    m.fix_normals()
    return m


def frame(direction, side_hint):
    """Rotation whose local X points along `direction` and local Z (the flat
    face's normal) points as close to `side_hint` as it can."""
    d = np.asarray(direction, float)
    d /= np.linalg.norm(d)
    w = np.cross(side_hint, d)
    w /= np.linalg.norm(w)
    n = np.cross(d, w)
    m = np.eye(4)
    m[:3, 0], m[:3, 1], m[:3, 2] = d, w, n
    return m


def mirror_x(mesh):
    m = mesh.copy()
    m.apply_transform(np.diag([-1, 1, 1, 1]))   # trimesh fixes the face order itself
    return m


def outline_shell(mesh, thickness):
    """Cartoon outline: a slightly bigger copy, turned inside out, drawn black.
    Only the back faces show, so it looks like a line round the edge."""
    m = mesh.copy()
    m.merge_vertices()
    m.vertices = m.vertices + m.vertex_normals * thickness
    m.invert()
    return m


def rotate_about(mesh, angle_deg, axis, point):
    m = mesh.copy()
    m.apply_transform(trimesh.transformations.rotation_matrix(math.radians(angle_deg), axis, point))
    return m


# ---- Faces and markings drawn flat, then bent onto a round body ----

def circle(c, r, n=48):
    """Outline of a circle in drawing pixels."""
    return [(c[0] + r * math.cos(2 * math.pi * i / n), c[1] + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def below_line(poly, a, b):
    """Keep the part of a convex outline below the line a-b (larger y in the drawing)."""
    def side(p):
        return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
    sign = 1 if side((a[0], a[1] + 1000)) > 0 else -1
    out = []
    for i, p in enumerate(poly):
        q = poly[(i + 1) % len(poly)]
        sp, sq = side(p) * sign, side(q) * sign
        if sp >= 0:
            out.append(p)
        if (sp >= 0) != (sq >= 0):
            k = sp / (sp - sq)
            out.append((p[0] + (q[0] - p[0]) * k, p[1] + (q[1] - p[1]) * k))
    return out


def front_mapper(radius_at, centre_x, bottom_y, studs_per_px):
    """For a round body (spun about +Y, standing on y = 0, facing -Z) drawn
    from the front: returns on_face(x, y, lift_px), the point on the body's
    front for drawing pixel (x, y), lifted lift_px off the skin.
    radius_at(height_in_studs) gives the body's radius."""
    def on_face(x, y, lift_px):
        h = (bottom_y - y) * studs_per_px
        mx = -(x - centre_x) * studs_per_px   # +x shows on the left of the front view
        r = max(radius_at(h), 1e-6)
        mx = max(-r * 0.98, min(r * 0.98, mx))
        z = -math.sqrt(r * r - mx * mx)
        n = np.array([mx, 0.0, z]) / r
        return np.array([mx, h, z]) + n * lift_px * studs_per_px
    return on_face


def bend_onto(on_face, outline_px, lift_px, thick_px, ring_px=None, max_edge=35):
    """A flat shape (or a band `ring_px` wide round its edge), drawn in
    pixels, bent onto a body with an on_face function from front_mapper.
    The shape is cut into small triangles first, so it follows the curve
    instead of cutting straight across it and dipping under the skin."""
    m = ring_shape(outline_px, ring_px, thick_px) if ring_px else flat_shape(outline_px, thick_px)
    v, f = trimesh.remesh.subdivide_to_size(m.vertices, m.faces, max_edge=max_edge)
    m = trimesh.Trimesh(v, f)
    m.vertices = np.array([on_face(x, y, lift_px + z) for x, y, z in m.vertices])
    m.fix_normals()
    return m


def srgb_to_linear(c):
    """GLB colours are stored as linear light, not as the 0-255 values in a
    colour picker. Without this the colours come out pale."""
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def export(path, parts, colours, extras=None, flat=()):
    """parts: {name: mesh}. colours: {name: (r, g, b, a)}. Writes a GLB with
    one node per part and a JSON sidecar with sizes, triangle counts and
    `extras` (pivots and anything the game script needs)."""
    scene = trimesh.Scene()
    info = {"parts": {}, "triangles": 0}
    for name, m in parts.items():
        m = m.copy()
        m.merge_vertices()
        if name in flat:   # thin flat parts (leaves) look best with hard edges
            m.unmerge_vertices()
        r, g, b, a = colours[name]
        mat = trimesh.visual.material.PBRMaterial(
            name=name, baseColorFactor=[srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), a / 255],
            alphaMode="BLEND" if a < 255 else "OPAQUE",
            metallicFactor=0, roughnessFactor=0.7, doubleSided=a < 255)
        m.visual = trimesh.visual.TextureVisuals(material=mat)
        scene.add_geometry(m, node_name=name, geom_name=name)
        tris = int(len(m.faces))
        info["parts"][name] = {"triangles": tris, "colour": [r, g, b],
                               "transparency": round(1 - a / 255, 2),
                               "centre": [round(float(v), 3) for v in m.bounds.mean(axis=0)],
                               "size": [round(float(v), 3) for v in m.extents]}
        info["triangles"] += tris
    lo, hi = scene.bounds
    info["size"] = [round(float(v), 3) for v in hi - lo]
    info.update(extras or {})
    scene.export(path, include_normals=True)
    with open(path.rsplit(".", 1)[0] + ".json", "w") as f:
        json.dump(info, f, indent=1)
    return info
