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
- [ ] The HUD shows the tree ring bar at the top ("Lv 1 Seedling · 1 rings") and a crosshair.
- [ ] Flies (small black balls) buzz around the field. Aim at one (it gets a yellow outline) and press **E** or **BITE**. Rings go up.
- [ ] At 4 rings you grow into a Budteryx: the plant gets bigger and a second slot button appears.
- [ ] Walk out through a gap in the tree ring. Big plants (level 3 and up) get pushed out of the field.
- [ ] Creatures in each territory have name labels and run from you. Eating one loads its power up into a slot (coloured button, coloured ball on your plant).
- [ ] Use a power up with **1**, **2**, **3** or the slot buttons. Try a special (bat flies, centipede runs fast, stick insect goes see-through, blowfish puffs up).
- [ ] NPC plants (named Sprouty, Chompers and so on) wander, eat and fight. Bite one smaller than you: it gets tossed, nuts spill, and a lost slot pops out as a fruit.
- [ ] Cow poo in the Grassland: touching it shows "Fertilised", and the next creature gives 2 to 6 rings.
- [ ] A rain cloud: a dark shadow shrinks over a territory, then rains. Standing in it gives rings.
- [ ] The swamp slows big plants, lily pads don't slow small ones, the river slows everyone off the bridges.
- [ ] Small plants fit through hollow logs (forest) and caves (hills); level 4 and up don't.
- [ ] At 94 rings a **TAKE ROOT** button appears. Rooting flashes the screen, builds a tree, adds 1 to Trees in the player list, and you start again as a Seedling with a fruit nearby.

To test rooting quickly, change `Levels.respawnRings` in
`src/shared/Config/Levels.luau` from 1 to 90, play, then change it back.

## 3. Things Claude couldn't check without Studio

These are the most likely to need a fix:

1. **Plant size per level** uses `Model:ScaleTo`. Check the plant doesn't float or sink at each level.
2. **Ramps**: bridge ramps and hill slopes are wedges; check they slope the right way.
3. **The aim outline** (Highlight) shows on the target.
4. **Phone layout**: in Studio, Test > Device emulator, try a small phone, a big phone, a tablet and desktop. Check the BITE and slot buttons don't cover the jump button or the thumbstick.
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
