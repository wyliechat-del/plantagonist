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
   (Rojo build, `lune run tests`, `selene src tests`, `stylua --check src tests`).
7. When a bug costs real time, add a line to "Known traps" below with the
   cause, so it isn't repeated.

## Conventions
- Files use the `.luau` extension. Folders that are modules use `init.luau`.
- Inside a folder module, require children with `require("@self/Name")`.
- Tests are `tests/<Name>.spec.luau`, returning `function(t)`; see
  `tests/lib/Test.luau` for `t.test`, `t.expect`, `t.expectEqual`.

## Known traps
- (none yet)
