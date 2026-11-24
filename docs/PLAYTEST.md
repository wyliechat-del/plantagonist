# Playtest guide (MVP)

The MVP was written without Studio, so nothing in it has run in Roblox yet.
The first job is a short solo test to catch crashes, then a group playtest.

## 1. Get the code into Studio

1. In Terminal: `cd ~/plantagonist && git fetch && git checkout claude/project-thread-4x3db6 && git pull`
2. Run `rojo serve`, open the Plantagonist place, then Plugins > Rojo > Connect.
3. For saving to work in Studio: in the Mac menu bar, open **File > Game
   Settings** (newer Studio versions call it **Experience Settings**), go to
   **Security** and turn on **Enable Studio Access to API Services**. Without it the game still runs;
   it prints one warning that saving is off.
4. Press **Play**. The map, creatures and HUD are built when the game
   starts, so in edit mode you only see the empty baseplate. Keep the **Output** window open (View > Output). Any line
   in red, or starting with `[Plantagonist] ... failed to start`, is a bug:
   copy it to Claude.

## 2. Solo check (about 10 minutes)

Tick each one, and note anything that looks wrong.

- [ ] You spawn in the glass conservatory as a small plant (pot, green head, brown root legs).
- [ ] The HUD shows the tree ring bar at the top ("Lv 1 Seedling · 1 rings").
- [ ] Flies (small black balls) buzz around the field. Point the mouse at one (it gets a yellow outline when it is in reach) and click, or tap it on a phone. Rings go up.
- [ ] At 4 rings you grow into a Budteryx: the plant gets bigger and a second slot button appears.
- [ ] Walk out through a gap in the tree ring. Big plants (level 3 and up) get pushed out of the field.
- [ ] Creatures in each territory have name labels and run from you. Eating one loads its power up into a slot (coloured button, coloured ball on your plant).
- [ ] Use a power up with **1**, **2**, **3** or the slot buttons. Try a special (bat flies, centipede runs fast, stick insect goes see-through, blowfish puffs up).
- [ ] NPC plants (named Sprouty, Chompers and so on) wander, eat and fight. Bite one smaller than you: it gets tossed, nuts spill, and a lost slot pops out as a fruit.
- [ ] Cow poo in the Grassland: touching it shows "Fertilised", and the next creature gives 2 to 6 rings.
- [ ] A rain cloud: a dark shadow shrinks over a territory, then rains. Standing in it gives rings.
- [ ] The swamp slows big plants, lily pads don't slow small ones, the river slows everyone off the bridges.
- [ ] Small plants fit through hollow logs (forest) and caves (hills); level 4 and up don't.
- [ ] At 80 rings a **TAKE ROOT** button appears. Rooting flashes the screen, grows a tree while the camera circles it, adds 1 to Trees in the player list, then shows RESPAWN; you start again as a Seedling with a fruit nearby.

To test rooting quickly, change `Levels.respawnRings` in
`src/shared/Config/Levels.luau` from 1 to 90, play, then change it back.

## 2b. New in build 2 (after playtest 1)

Check these first:

1. **Flies** are slower and only feed a plant up to 4 rings.
2. **Creatures** walk slower, only dodge when you're close (about 6 studs), and walk round hills instead of through them. About 3 in 10 spawn outside their home territory.
3. **Boosts**: bee, mantis and bombardier beetle no longer take a slot. With a matching attack loaded, the slot gets a dot; without one you see "Bee needs a Venom attack."
   - Bee: the venom attack's lockout lasts twice as long.
   - Mantis: the boosted attack is kept once instead of used up.
   - Bombardier beetle: the hit also knocks out the victim's oldest power up.
4. **Slot buttons** say the attack type (Venom, Slash, Strangle) or the move (Fly, Puff, Dash, Hide). Ranged has a triangle, melee is a square button, specials are round.
5. **Rain warning**: a dark shadow, the cloud overhead, glowing rings that close in on the spot, then lightning and thunder in the last 3 seconds.

## 2c. New in build 3 (after playtest 2)

1. **Clicking and tapping**: bite by clicking (desktop) or tapping (phone) on a creature or plant in reach. Clicking empty ground snaps at the air with a white puff and the usual wait. Clicking something out of reach does nothing. The BITE button and the crosshair are gone.
2. **Power ups**: tap a slot (or press 1 to 3) to prime it; it gets a red ring and the outline turns red. The next click uses it. Ranged attacks fire toward the click even if nothing is there. Tap the slot again to cancel. Fly, Puff, Dash and Hide go off as soon as you tap them.
3. **Levels**: levels start at 1, 4, 10, 20, 36 and 57 rings; rooting at 80. Levels 1 to 3 are 20% faster. Creatures give 2, 3 or 4 rings by size; cow poo gives 3 to 8.
4. **Creatures** wander slower and run for 1.5 s when you get close.
5. **Range**: ranged attacks reach 15 studs plus 5 per level (35 at level 4).
6. **Cows**: at level 5 or more, bite a cow to pick it up; after a second it is tossed. No rings.

## 2d. New in build 4 (after playtest 3)

1. **Speed**: levels 1 to 3 run at about 17 studs a second, levels 4 to 6 at 12.
2. **Reach**: bites and melee power ups reach 7.5 studs from the plant's edge at every level; ranged attacks reach 45.
3. **Roar**: a level 4 to 6 plant biting or melee hitting a plant roars first (its head flashes red for 0.25 s). Dart out of reach during the roar and it misses. Bites on creatures don't roar.
4. **Lift and toss**: when a level 4 to 6 plant hits a smaller plant, the small plant is held in its mouth for 0.5 s, then tossed the way the big plant faces.
5. **Rooting**: the camera circles your tree while it grows (3 s) and drops its first fruit. Then RESPAWN shows; after 20 s you respawn anyway.
6. **Flight**: Fly rises to about 18 studs, zooms at 25 studs a second for 6 s (steer with WASD or the thumbstick), then glides down. Ranged shots fired while flying home in on the plant nearest your click.
7. **Creatures** hop when frightened and run at 6 for 1.5 s.

Studio risks for build 4: the lifted plant is anchored and moved by the server, so check it lets go cleanly; flight uses a LinearVelocity on your own client, so check it steers on a phone too.

## 2e. New in build 5 (after playtest 4)

1. **Build flag**: a green flag next to the spawn pad says "Build 5". If it shows an older number, Studio hasn't synced.
2. **Stagger**: a level 4 to 6 plant that gets hit pauses for 0.25 s and steps back (unless a bigger plant lifts it).
3. **Reach**: bites and melee power ups reach 9 studs; ranged attacks reach 50.
4. **Creatures** stay startled 25% longer (about 1.9 s).
5. **Slash**: the red family is called Slash now.
6. **Jump**: 20% faster while in the air, and 1 s after landing before you can jump again.

## 2f. New in build 6: the conservatory model

The conservatory now uses the 3D model made from Wylie's art. Until the model
is imported, the game shows the old plain glass walls, so do this once:

1. Pull the branch as in section 1. The model is `models/Conservatory.glb`.
2. Studio needs the place published (it is). In edit mode, open
   **File > Import** (Command + M; some versions call it **Import 3D**) and pick
   `~/plantagonist/models/Conservatory.glb`. Leave the import settings as
   they are and press **Import**. This uploads the meshes, the roof image and
   the sign images to your account.
3. A model named **Conservatory** appears in Workspace. In the Explorer,
   drag it from **Workspace** onto **ServerStorage**. The game copies it
   from there when it starts. (It stays in the place file, not in Git:
   Rojo 7.5 can't read models saved by current Studio.)
4. Save the place: **File > Save to Roblox**.

Then press **Play** and check:

1. **Build flag** says "Build 6".
2. **Walls**: peach walls, brown depth, 6 arched windows and a door on each side, sitting on the ground (not floating or sunk).
3. **Glass**: windows and the stained glass roof are see-through (60%).
4. **Signs**: "Dangerous Plants" over each outside door, the Warning sign over each inside door. If the space around the letters shows as a coloured box instead of wall, tell Claude.
5. **Coloured light**: pink, blue, yellow and orange pools of light on the floor inside. Rojo now sets **Lighting > Technology** to **Future** so these lights show properly; phones lower it on their own if needed.
6. **Doors**: plants walk in and out of all 4 doors, and can't pass through the walls or windows.

## 3. Things Claude couldn't check without Studio

These are the most likely to need a fix:

1. **Plant size per level** uses `Model:ScaleTo`. Check the plant doesn't float or sink at each level.
2. **Ramps**: bridge ramps and hill slopes are wedges; check they slope the right way.
3. **The outline** (Highlight) shows on what is under the mouse, or the nearest thing in reach on a phone. Taps on a phone land where you tap (tap positions and mouse positions are measured differently, so check both).
4. **Phone layout**: in Studio, Test > Device emulator, try a small phone, a big phone, a tablet and desktop. Check the slot buttons don't cover the jump button or the thumbstick.
5. **Being tossed and bat flight** feel OK (they run on your own client).
6. **NPCs** move and don't get stuck on the conservatory walls.
7. **Sounds** are built-in Studio sounds as placeholders; some may be silent.

## 4. Group playtest (from the design doc)

- 4 to 8 people, 2 or 3 sessions, at least half on phones. Publish the place
  first (File > Publish to Roblox) and add friends as collaborators or use a
  private server.
- Ask after each session: what was most fun, when was it boring, what was confusing.
- The server Output logs each player's time to each level (`[Log] ReachedLevel4 ...`),
  every level drop with its cause, rooting, and session length. The same
  events go to Creator Hub > Analytics > Custom events. Send these to Claude
  to retune Config.
