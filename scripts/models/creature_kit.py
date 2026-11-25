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
