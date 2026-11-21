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
- [ ] At 80 rings a **TAKE ROOT** button appears. Rooting flashes the screen, builds a tree, adds 1 to Trees in the player list, and you start again as a Seedling with a fruit nearby.

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
4. **Slot buttons** say the attack type (Venom, Bite and slash, Strangle) or the move (Fly, Puff, Dash, Hide). Ranged has a triangle, melee is a square button, specials are round.
5. **Rain warning**: a dark shadow, the cloud overhead, glowing rings that close in on the spot, then lightning and thunder in the last 3 seconds.

## 2c. New in build 3 (after playtest 2)

1. **Clicking and tapping**: bite by clicking (desktop) or tapping (phone) on a creature or plant in reach. Clicking empty ground snaps at the air with a white puff and the usual wait. Clicking something out of reach does nothing. The BITE button and the crosshair are gone.
2. **Power ups**: tap a slot (or press 1 to 3) to prime it; it gets a red ring and the outline turns red. The next click uses it. Ranged attacks fire toward the click even if nothing is there. Tap the slot again to cancel. Fly, Puff, Dash and Hide go off as soon as you tap them.
3. **Levels**: levels start at 1, 4, 10, 20, 36 and 57 rings; rooting at 80. Levels 1 to 3 are 20% faster. Creatures give 2, 3 or 4 rings by size; cow poo gives 3 to 8.
4. **Creatures** wander slower and run for 1.5 s when you get close.
5. **Range**: ranged attacks reach 15 studs plus 5 per level (35 at level 4).
6. **Cows**: at level 5 or more, bite a cow to pick it up; after a second it is tossed. No rings.

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
