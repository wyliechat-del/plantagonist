"""Check a .blend file against Roblox limits and export it as FBX for Studio.

Run with Blender in the background (no window opens):

    blender --background models/Pot.blend --python scripts/blender/export_roblox.py

On a Mac, `blender` is /Applications/Blender.app/Contents/MacOS/Blender.

Options go after a lone `--`:

    --out DIR        where the .fbx goes (default: models/export)
    --max-tris N     triangle limit per mesh (default: 20000, the Roblox limit)
    --check-only     run the checks but don't write a file

Exits with code 1 if any check fails, so it can gate a build like the
other checks. Convention: 1 Blender unit = 1 stud, Scene > Units > Unit
System = None. In the Studio importer, keep Scale Unit on Stud.
"""

import argparse
import os
import sys

import bpy

# Roblox caps each MeshPart at 20,000 triangles.
ROBLOX_MAX_TRIS = 20000
# Anything over this gets a warning, not a failure: smaller meshes load faster.
SOFT_MAX_TRIS = 10000


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(prog="export_roblox.py")
    parser.add_argument("--out", default=None)
    parser.add_argument("--max-tris", type=int, default=ROBLOX_MAX_TRIS)
    parser.add_argument("--check-only", action="store_true")
    return parser.parse_args(argv)


def triangle_count(obj, depsgraph):
    """Triangles after modifiers, which is what gets exported."""
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    try:
        mesh.calc_loop_triangles()
        return len(mesh.loop_triangles)
    finally:
        evaluated.to_mesh_clear()


def check_scene(max_tris):
    scene = bpy.context.scene
    depsgraph = bpy.context.evaluated_depsgraph_get()
    errors, warnings = [], []

    units = scene.unit_settings
    if units.system != "NONE" or abs(units.scale_length - 1.0) > 1e-6:
        warnings.append(
            "Scene > Units should be Unit System = None, Unit Scale = 1 "
            "(1 Blender unit = 1 stud). Sizes below assume that."
        )

    meshes = [o for o in scene.objects if o.type == "MESH" and o.visible_get()]
    if not meshes:
        errors.append("No visible mesh objects in the scene.")

    total = 0
    for obj in meshes:
        tris = triangle_count(obj, depsgraph)
        total += tris
        x, y, z = obj.dimensions
        # Blender is Z-up, Roblox is Y-up, so height is Blender Z.
        print(f"  {obj.name}: {tris} triangles, {x:.2f} x {z:.2f} x {y:.2f} studs (W x H x D)")

        if tris > max_tris:
            errors.append(f"{obj.name} has {tris} triangles; the limit is {max_tris}. Add a Decimate modifier.")
        elif tris > SOFT_MAX_TRIS:
            warnings.append(f"{obj.name} has {tris} triangles; under {SOFT_MAX_TRIS} is better for phones.")

        if any(s < 0 for s in obj.scale):
            errors.append(f"{obj.name} has a negative scale, which flips faces in Roblox. Apply scale (Ctrl+A).")
        elif any(abs(s - 1.0) > 1e-4 for s in obj.scale):
            warnings.append(f"{obj.name} scale is not applied. Ctrl+A > Scale in Blender keeps sizes predictable.")

        if not obj.data.uv_layers:
            warnings.append(f"{obj.name} has no UV map, so textures won't line up.")
        if not any(slot.material for slot in obj.material_slots):
            warnings.append(f"{obj.name} has no material.")

    print(f"  Total: {total} triangles in {len(meshes)} mesh(es)")
    return errors, warnings


def export_fbx(out_dir):
    blend_path = bpy.data.filepath
    name = os.path.splitext(os.path.basename(blend_path))[0] if blend_path else "untitled"
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name + ".fbx")
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_visible=True,
        object_types={"MESH", "ARMATURE", "EMPTY"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="-Z",
        axis_up="Y",
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="COPY",
        embed_textures=True,
    )
    return path


def default_out_dir():
    blend_path = bpy.data.filepath
    base = os.path.dirname(blend_path) if blend_path else os.getcwd()
    return os.path.join(base, "export")


def main():
    args = parse_args()
    print(f"Checking {bpy.data.filepath or '(unsaved file)'}")
    errors, warnings = check_scene(args.max_tris)

    for w in warnings:
        print(f"WARNING: {w}")
    for e in errors:
        print(f"ERROR: {e}")

    if errors:
        print("Checks failed; nothing exported.")
        sys.exit(1)

    if args.check_only:
        print("Checks passed.")
        return

    path = export_fbx(args.out or default_out_dir())
    print(f"Exported {path}")
    print("In Studio: File > Import 3D, pick this file, keep Scale Unit on Stud.")


main()
