# Making a creature model

Creatures are built by a Python script from Wylie's drawing, previewed as
pictures, and only then imported into Studio. The fly was the first.

## What the drawing needs
- Front and side views at least; a three quarter view helps. A top view helps
  for anything seen from above (the game camera is often high).
- Flat colours. Each colour becomes one part, so few colours means few parts.
- Say which bits move (wings, tails) and which are see-through, and by how much.

## Steps
1. Save the drawing as `models/creatures/art/<name>-drawing.png`.
2. Write `scripts/models/build_<name>.py` using the shapes in
   `scripts/models/creature_kit.py` (ellipsoids, tubes for legs, flat shapes
   for wings, mirror, cartoon outline shell). Copy `build_fly.py` as a start.
   Measure sizes from the side view in pixels and note them at the top.
3. Build: `python3 scripts/models/build_<name>.py models/creatures/<Name>.glb`.
   It also writes `<Name>.json`: each part's colour, transparency, size,
   triangle count, and the hinge and axis for moving parts.
4. Preview (needs Node and Playwright; cloud sessions have both):
   `cd scripts/models/preview && npm install && cd -`, then
   `node scripts/models/preview/render.mjs models/creatures/<Name>.glb OUT_DIR`.
   It writes `views.png` (front, three quarter, side, top), `views-plain.png`
   (no outline) and `motion.gif` when the JSON lists moving parts (`moving`: parts, hinge,
   axis, swing range in degrees, swings per loop).
5. Show Wylie the previews. Change, rebuild and preview until approved.
6. After approval: Wylie imports the GLB in Studio (File > Import) and keeps
   the model in ServerStorage (see Known traps in CLAUDE.md about `.rbxm`).
   The game script then sets each see-through part's Transparency and turns
   moving parts about their hinges, using the numbers from the JSON (copied
   into `src/shared/Config/`).

## Rules learned so far
- Roblox ignores see-through pixels in imported textures. See-through parts
  are plain coloured parts whose Transparency the game sets (fly wings: 0.6).
- The fly's legs are one part that swings 15 degrees about the middle hips.
- Anything that moves is its own part, so a script can turn it.
- Axes: +Y up, the creature faces -Z (Roblox's forward), 1 unit = 1 stud.
- The black cartoon outline is a separate `Outline` part (a slightly bigger
  inside-out copy). Delete it for a plain look; wing rims go with it.
