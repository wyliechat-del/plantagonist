# Blender: making 3D models for Plantagonist

Blender is free 3D software. We use it for meshes (plants, pots, props), then
import them into Roblox Studio as MeshParts.

## Install (once)

1. Go to <https://www.blender.org/download/> and download Blender for macOS.
   Pick **Apple Silicon** if your Mac has an M1 or newer chip (Apple menu >
   About This Mac shows "Chip: Apple M..."), otherwise **Intel**.
2. Open the downloaded `.dmg` and drag Blender into **Applications**.
3. Open Blender from Applications. If macOS says it can't check the app,
   open System Settings > Privacy & Security and click **Open Anyway**.
4. Check the command line can find it. In Terminal:
   ```sh
   /Applications/Blender.app/Contents/MacOS/Blender --version
   ```
   It should print `Blender 5.x`.
5. Optional shortcut so you can type `blender`: add this line to `~/.zshrc`,
   then open a new Terminal window:
   ```sh
   alias blender=/Applications/Blender.app/Contents/MacOS/Blender
   ```

## Set up a new model file

1. In Blender: File > New > General. Delete the default camera and light
   (select, press X) if you don't need them.
2. Properties panel > **Scene** tab (cone icon) > Units: set **Unit System** to
   **None**. Now 1 Blender unit = 1 stud. A player is about 5 studs tall.
3. Save the file as `models/<Name>.blend` in the repo, using the name the model
   will have in the game, for example `models/Sunflower.blend`.

## Rules for Roblox-ready models

- **Under 20,000 triangles per mesh** (Roblox's hard limit). Aim for under
  10,000 so the game runs well on phones. Use a Decimate modifier to cut detail.
- **Apply scale** before exporting: select the object, Ctrl+A > Scale.
  Never leave a negative scale; it turns faces inside out in Roblox.
- **UV unwrap** anything that gets a texture (Edit Mode, U > Smart UV Project).
- Textures as `.png`, 1024 x 1024 or smaller.
- One object in Blender becomes one MeshPart in Roblox. Join parts that should
  move together (Ctrl+J).

## Export and check

From the repo folder in Terminal:

```sh
blender --background models/Sunflower.blend --python scripts/blender/export_roblox.py
```

The script lists every mesh with its triangle count and size in studs, warns
about common mistakes, and fails (writes nothing) if a mesh is over the limit.
If it passes it writes `models/export/Sunflower.fbx`. To only run the checks,
add `-- --check-only` at the end.

Exports are not committed (they are made from the `.blend`), so the `.blend` is
the file that matters.

## Import into Studio

1. Studio > Home or Avatar tab > **Import 3D** (or File > Import 3D).
2. Pick the `.fbx` from `models/export/`.
3. In the import window keep **Scale Unit** on **Stud**, check the preview
   size looks right, then click **Import**.
4. The model arrives in the Workspace. Move it into a folder that makes sense
   (for example `ReplicatedStorage.Models`) if game code will clone it.

Importing in Studio uploads the mesh to your Roblox account. Later we can
upload straight from the command line with Open Cloud, which needs the
`asset:read` and `asset:write` scopes added to the API key.

## Letting Claude drive Blender

Claude can run the export script above on your Mac through a Remote Control
session, so it can check and export models for you. Claude can also write
Blender Python scripts that build simple shapes (pots, crates, fences) from
code. A live connection where Claude moves things in an open Blender window
(Blender MCP) is possible later; it needs extra installs, so we'll add it only
if the script route isn't enough.
