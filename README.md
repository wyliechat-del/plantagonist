# Plantagonist

A Roblox game. All code lives in this repo and syncs into Roblox Studio with
[Rojo](https://rojo.space). Code is never typed straight into Studio.

## Layout

| Path | What goes there |
| --- | --- |
| `src/shared/Config/` | Every tweakable number (speeds, costs, timers). Plain tables only. |
| `src/shared/Rules/` | Game logic as plain Luau functions, testable without Roblox. |
| `src/shared/Remotes.luau` | The one list of every client/server message. |
| `src/server/` | Server scripts (ServerScriptService). `Services/` holds one module per system (map, plants, creatures, combat, rain, rooting, NPCs, data). |
| `src/client/` | Client scripts (StarterPlayerScripts). `Controllers/` holds the HUD, controls and effects. |
| `tests/` | Unit tests, run with Lune on a normal computer. |
| `sim/` | Ring economy simulator: `lune run sim`. Player behaviour guesses are in `sim/Assumptions.luau`. |
| `scripts/check.sh` | Runs the four checks. |
| `models/` | Blender source files (`.blend`) for 3D models. See `docs/blender.md`. |
| `scripts/blender/` | Blender scripts: `export_roblox.py` checks a model and exports it for Studio. |

Rojo puts `src/shared` in ReplicatedStorage as `Shared`, `src/server` in
ServerScriptService as `Server`, and `src/client` in StarterPlayerScripts as
`Client`.

## First-time setup on your computer

1. Install [Git](https://git-scm.com/downloads) and [Rokit](https://github.com/rojo-rbx/rokit#installation).
2. Clone the repo and install the pinned tools:
   ```sh
   git clone https://github.com/wyliechat-del/plantagonist.git
   cd plantagonist
   rokit install
   ```
3. Install the Rojo plugin in Studio: run `rojo plugin install`, then restart Studio.
4. Recommended editor: VS Code, with the extensions listed in `.vscode/extensions.json`.

## Working in Studio

1. In the repo folder, run `rojo serve`.
2. Open Studio with a new Baseplate (or the published place).
3. Plugins tab > Rojo > Connect. Studio now mirrors the files in `src/`.
4. Edit files on disk, not scripts in Studio. Changes appear in Studio on save.

## The four checks

Run `./scripts/check.sh` (on Windows, run it from Git Bash). It runs:

1. `rojo build` (the project builds into a place file)
2. `lune run tests` (unit tests)
3. `selene src` and `selene --config tests/selene.toml tests sim` (lint; tests and the simulator use plain Luau rules because they run in Lune)
4. `stylua --check src tests sim` (format; run `stylua src tests sim` to fix)

GitHub runs the same checks on every push and pull request.

## Playtesting

How to run the game in Studio and what to check: [docs/PLAYTEST.md](docs/PLAYTEST.md).

## 3D models

Models are made in Blender and imported into Studio as MeshParts. Setup,
rules and the export command are in [docs/blender.md](docs/blender.md).

## Secrets

API keys (such as the Roblox Open Cloud key) go in environment variables or a
local `.env` file, never in Git or chat. Copy `.env.example` to `.env` to start.
`.env` is ignored by Git.

## Balancing the game

Game numbers live in `src/shared/Config/`. After changing one, run
`lune run sim` to see how long players take to reach each level, compared
with the targets in the design doc. The simulator uses the real Rules and
Config, plus guesses about player behaviour in `sim/Assumptions.luau`.
