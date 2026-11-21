# Plantagonist: rules for working in this repo

Roblox game. Code syncs into Studio with Rojo (`default.project.json`).

## Standing rules
1. Code lives in files in this repo. Never edit scripts inside Studio; Studio
   and files drifting apart is how a project gets lost.
2. Every tweakable number goes in `src/shared/Config/`. No magic numbers in
   game code.
3. Every RemoteEvent or RemoteFunction is listed in `src/shared/Remotes.luau`
   and fetched through `Remotes.event` / `Remotes.func`. Nothing else creates
   remotes.
4. Game logic goes in `src/shared/Rules/` as pure Luau (no `game`, services or
   Instances) so it can be unit tested with Lune. Scripts under `src/server`
   and `src/client` stay thin and call into Rules.
5. API keys only in environment variables or an untracked `.env`. Never commit
   or print one.
6. All four checks must pass before a change is done: `./scripts/check.sh`
   (Rojo build, `lune run tests`, Selene lint, `stylua --check src tests`).
7. When a bug costs real time, add a line to "Known traps" below with the
   cause, so it isn't repeated.

## Conventions
- Files use the `.luau` extension. Folders that are modules use `init.luau`.
- Modules in `Config/` and `Rules/` require nothing, so they load the same in
  Roblox and in Lune. Rules take Config values as arguments. Game scripts
  require them with `require(ReplicatedStorage.Shared.Rules.Growth)`; tests
  with `require("../src/shared/Rules/Growth")`.
- Tests are `tests/<Name>.spec.luau`, returning `function(t)`; see
  `tests/lib/Test.luau` for `t.test`, `t.expect`, `t.expectEqual`.
- The ring economy simulator is `sim/` (`lune run sim`). It uses the real
  Rules and Config; its player behaviour guesses live in `sim/Assumptions.luau`,
  not in Config. Run it after changing economy numbers.
- 3D models: `.blend` sources in `models/`, 1 Blender unit = 1 stud (Unit
  System None). Export and check with `scripts/blender/export_roblox.py`
  (fails over 20,000 triangles per mesh). Guide: `docs/blender.md`.

## Known traps
- Selene's `roblox` std rejects string requires (`require("./x")`), so `src`
  uses Instance requires and `tests/` is linted with its own
  `tests/selene.toml` (plain Luau std).
- In Lune, `./` inside a folder's `init.luau` means the folder's parent, not
  the folder. Use `@self/x` for files next to an `init.luau`.
