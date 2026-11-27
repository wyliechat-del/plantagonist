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
3. **Glass**: windows are 60% see-through; on the roof the dark grey leading is solid and the coloured glass is 60% see-through.
4. **Signs**: "Dangerous Plants" over each outside door, the Warning sign over each inside door. If the space around the letters shows as a coloured box instead of wall, tell Claude.
5. **Coloured light**: pink, yellow, green and orange pools of light on the floor inside. Rojo now sets **Lighting > Technology** to **Future** so these lights show properly; phones lower it on their own if needed.
6. **Doors**: plants walk in and out of all 4 doors, and can't pass through the walls or windows.

## 2g. New in build 7: the River quarter

The flag should read "Build 7". Walk out of the safe field into the River
quarter (top left from above) and check:

1. **River**: blue terrain water with small waves winds from the top edge to
   the left edge. You wade through it (no swimming) at about 60% speed.
2. **Moon bridge**: a grey stone arch. Walk over it. At level 4 or below you
   can also walk under the middle through the water; level 5 bumps into it.
3. **Paver path** of separate stones runs from the moon bridge to a black
   iron **gate** with three cream pillars and lit lamps in the top wall.
4. **Marsh**: brown mud with reeds. Levels 1 to 3 move at full speed,
   levels 4 to 6 slower.
5. **Lily pads** with a notch cut out. Land on one and you spring up and can
   steer for about 0.75 s; land on another and you spring again.
6. **Rope bridge** to the Hills sways a little. **Rock ford** near the left
   edge: walk across on the rocks without jumping.
7. **Hiding grass** (two pale circles): at level 1 to 3 you look see-through
   to yourself and another player can't see you, only your name. Bite
   something and you show for 3 seconds.
8. Blowfish appear in the river and toads on the marsh; other creatures stay
   on dry land.

## 2h. New in build 8: River quarter fixes

1. **Gate** has a side gate at each end and a big brass padlock on the
   middle post.
2. **Loose stone wall** runs from the gate east to the river, and west to
   the corner and down the left edge to the river.
3. **Moon bridge** is higher (15 in the middle): a level 4 walks under
   without its head going through. Level 5 now fits too.
4. **Ford**: more loose rocks up and down the river, and white spray on the
   upstream rocks.
5. **Lily pads**: three times as many, plus 22 white water lilies. The hop
   is lower (about 10 studs).
6. **Rope bridge** swings like a cradle from the post tops. Standing on it
   should feel smooth, with no camera shake.

## 2i. New in build 9: the Hills quarter

Walk out of the field to the top right (the Hills).

1. **Ground** is grey slate terrain with patches of sand and grass, and
   about 40 cacti (ball, short with two arms, tall with three). You walk
   through cacti.
2. **First Rise** (light brown) is one jump up (6). **Second Rise** (medium
   brown) is one more jump (12). **Third Rise** (dark brown, 24) can't be
   jumped onto, and bat flight can't get over it from the ground.
3. Cliff edges have leaning rock slabs, so they look broken up, not
   straight.
4. **Two ramps** (light brown) lead from the ground up to the First Rise.
5. **Tunnels** at ground level: levels 1 to 3 walk through, level 4 can't
   get in. The big tunnel has a **cave** in the middle with miner's
   lanterns on chains. Walking on the rock above the tunnels works.
6. **Bottom left hill**: walk up one side, over the top and down the other;
   a tunnel runs through it lengthways.
7. **Cliff wall** of grey rock with grass on top runs along the top and
   right edges, from the river to a tall pillar where the Grassland starts.
8. **Spawns**: bats (the Hills creature with the Fly move) appear in the
   tunnels, chameleons on the First Rise. Others don't go into tunnels.

## 2j. New in build 10: Hills fixes

1. The slate stops at the edge of the safe field; the field is grass again.
2. Ball cacti are barrel cacti: ribbed, with a pale top and spines.
3. **Tunnels** have arched roofs, 10 high in the middle and 7 at the
   walls. Level 3 walks through; level 4 (about 12 tall) can't get in.
4. **Rises**: First 12 (a stud over the tunnel roofs; use a ramp or fly
   up), Second 18 (one jump from the First), Third 30. The pillar right
   of centre is 12, 24 and 48.
5. **Cave**: arched, 14 high, with 6 lanterns on its walls. Tunnels have a
   wall lantern every 24 studs.
6. **Bottom left hill** is 12 high with the arched tunnel through it.
7. **Sand** round the foot of every cliff on the ground, wider in places.
   The loose sand patches are gone (grass patches stay).
8. **Ramps** are longer (out into the ground) and in three pieces: a lower
   slope, a ledge and an upper slope, turned a little from each other,
   with Second Rise boulders along the sides.

## 2k. Build 11 (replaced by build 12)

Build 11 tried ray-placed lanterns and cacti, ramp boulders, a dressed
bottom left hill, wider cliff sand, attacks blocked by rock, and flying
bats. The flying bats are gone in build 12; the cave lanterns are fixed;
cacti come next.

## 2l. New in build 12: the cave

1. Four miner's lanterns in the cave, two on each long wall, clear of the
   rock face. The Output window says "Hills: 4 cave lanterns placed".
2. The decorative flying bats are gone.
3. Bat creatures still spawn in the tunnels and cave, but now wander
   slowly (40% of normal creature speed) and can leave the tunnels onto
   the Hills ground and the First Rise.

## 2m. New in build 12B: cave grass and cacti

1. No grass patches in the cave or tunnels (grass patches only go on open
   ground, clear of rock).
2. Cacti stand on the slate, set in 0.3 studs. Output says
   "Hills: 40 cacti, feet from ... to ... studs high; 0 surface rays
   missed". Feet on the ground should read about 0 (or a bit under); if
   rays missed is above 0, tell Claude.
3. Each cactus on the ground has sand round its foot, 6 to 12 studs
   across (in 4 stud terrain squares).
4. The flag says Build 12B.

## 2n. New in build 12C: barrel cacti sit on the ground

1. The round barrel cacti are rounder and sit on top of the ground (and
   sand): you see the whole ribbed ball, with only its rounded bottom
   touching the ground.
2. Tall and short cacti are unchanged.
3. The flag says Build 12C.

## 2o. New in build 12D: tunnel grass and round barrels

1. No grass in any tunnel, the cave or on the bottom left hill (grass
   patches keep clear of all of them).
2. Barrel cacti are nearly round balls, widest half way up, with the whole
   ball above the ground. If they float, lower `barrelLift` in
   Config/Map.
3. The flag says Build 12D.

## 2p. New in build 12E: barrels on top of the ground

1. Barrel cacti (same design as 12D) sit fully on top of the ground, even
   on slopes: each stands on the highest ground under its ball, lifted
   `barrelLift` (2 studs). If they float, lower it in Config/Map.
2. Output prints "Hills: first barrel ray hit ..." (what the ray stood the
   barrel on); send that line to Claude if barrels still look wrong.
3. No cacti on the bottom left hill.
4. The flag says Build 12E.

## 2q. New in build 13: the first (bottom left) hill

From Wylie's drawing of 2026-11-27.

1. The hill has the uneven outline from the drawing, with steep First Rise
   rock sides and leaning slabs like the other rises, 12 studs high.
2. The tunnel along it is as before (same walls, arched roof, lanterns).
3. Two ramps, one down each long side as drawn, in pieces (slope, ledge,
   slope) in the same stone colour as the other ramps, with boulders like
   the other ramps. Each has ragged broken pieces at its low end. The
   right ramp meets the foot of the big ramp next to it.
4. Sand round the foot of the hill and round its ramps.
5. Four clusters of rough Second Rise boulders on top, where the dark
   patches are in the drawing. No boulders on the old slopes, no cacti.
6. The flag says Build 13.

## 2r. New in build 13B: boulder heights

1. Rise Two boulders on terrain (the hill top, the ground round the
   ramps) sit on the ground, lifted `boulderTerrainLift` (2 studs) like
   the barrel cacti, instead of showing as thin slivers.
2. No boulders in or at the edge of the river.
3. The flag says Build 13B.

## 2s. New in build 13C: chunky boulders on the first hill

1. The boulder clusters on the first hill stand up as chunky rough blocks
   like the boulders on the other ramps, not flat shapes in the rock.
2. Output prints "Hills: N of M boulders found the ground lower than the
   map height (by up to X studs)"; send that line to Claude.
3. The flag says Build 13C.

## 2t. New in build 13D: boulders are chunky again

1. Every Rise Two boulder is a chunky rough block (they were flat sheets:
   their height came from a whole-number roll, so 0.55 to 0.9 gave 0).
   They sit on the ground the ray finds, with no extra lift.
2. Boulders on the ramps are spread along and across the ramp instead of
   lining up at its ends and middle.
3. The flag says Build 13D.

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
