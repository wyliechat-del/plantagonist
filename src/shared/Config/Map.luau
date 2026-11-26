--[[
	Map layout in studs. The centre of the map is (0, 0). The conservatory sits
	in the middle of a round safe field; the four territories are the quarters
	of the square map around it.

	Quarters: Grassland is +X +Z, Forest is -X +Z, River is -X -Z, Hills is +X -Z.
]]

local Map = {}

-- Half the width of the square map (so the map is 700 x 700).
Map.halfSize = 350
Map.groundY = 0
Map.wallHeight = 60

Map.territories = table.freeze({
	Grassland = table.freeze({ signX = 1, signZ = 1, colour = table.freeze({ 120, 190, 90 }) }),
	Forest = table.freeze({ signX = -1, signZ = 1, colour = table.freeze({ 60, 120, 60 }) }),
	River = table.freeze({ signX = -1, signZ = -1, colour = table.freeze({ 90, 150, 120 }) }),
	Hills = table.freeze({ signX = 1, signZ = -1, colour = table.freeze({ 150, 140, 100 }) }),
})

-- The conservatory building in the centre. The look comes from the model
-- named `modelName` in ServerStorage (built by
-- scripts/models/build_conservatory.py and imported in Studio); invisible walls give it collision. Without the model,
-- plain glass walls stand in.
Map.Conservatory = table.freeze({
	halfSize = 30,
	height = 22,
	wallThickness = 2,
	-- The doorway plants walk through: inner width of the door arch, and the
	-- height where the arch starts curving.
	doorWidth = 10.4,
	doorHeight = 10,
	modelName = "Conservatory",
	-- Colours of the model's parts, by part name (from Wylie's panel art).
	colours = table.freeze({
		WallFace = table.freeze({ 243, 212, 158 }),
		WallDepth = table.freeze({ 142, 90, 68 }),
		Frame = table.freeze({ 226, 156, 122 }),
		Glass = table.freeze({ 200, 255, 220 }),
		Grille = table.freeze({ 142, 142, 142 }),
	}),
	glassTransparency = 0.6,
	-- The roof and signs are shown as decals, which keep the see-through
	-- parts of their images (the roof image has opaque leading and 60%
	-- see-through glass). This is how far each decal part sits off its
	-- surface, and how thick it is.
	decalOffset = 0.05,
	-- Image asset ids for the decals (from Studio's Asset Manager). 0 means
	-- read the image from the imported part instead.
	imageIds = table.freeze({
		Roof = 0,
		SignOutside = 0,
		SignInside = 0,
	}),
	decalThickness = 0.1,
	-- Coloured light under the stained glass roof: a grid of downward spot
	-- lights, cycling through the roof glass colours.
	roofLights = table.freeze({
		perSide = 4,
		belowRoof = 1,
		range = 24,
		angle = 70,
		brightness = 3.5,
		-- Which colour each light uses, row by row (indexes into `colours`),
		-- so every colour appears 4 times, scattered over the room.
		pattern = table.freeze({ 1, 2, 3, 4, 3, 4, 1, 2, 4, 3, 2, 1, 2, 1, 4, 3 }),
		colours = table.freeze({
			table.freeze({ 203, 33, 162 }),
			table.freeze({ 222, 211, 20 }),
			table.freeze({ 57, 181, 74 }),
			table.freeze({ 220, 117, 66 }),
		}),
	}),
})

-- The safe field around the conservatory, ringed by trees with gaps.
Map.Field = table.freeze({
	radius = 75,
	-- Plants above this level can't be inside the field (they are pushed out).
	maxLevel = 2,
	-- Exits through the tree ring, as angles in degrees inside each quarter.
	exitAnglesInQuarter = table.freeze({ 22.5, 45, 67.5 }),
	exitWidthDegrees = 10,
	treeSpacingDegrees = 3,
	-- How far outside the field edge a pushed-out plant lands.
	pushOutMargin = 6,
})

--[[
	River quarter (redesigned 2026-11-26 from Wylie's map). Points are
	{ x, z } in studs, traced from the map picture
	(/mnt/project-files/plantagonist/art/map-redesign/wylie-revised-map.png).
]]

local function points(list: { { number } }): { { number } }
	for _, point in list do
		table.freeze(point)
	end
	return table.freeze(list)
end

-- River: winds from the top edge, along the Hills border, past the safe
-- field and out of the left edge. Plants wade through it anywhere, slowly.
Map.River = table.freeze({
	-- Centre line, from the top edge to the left edge.
	centreLine = points({
		{ -21, -356 },
		{ -21, -265 },
		{ -29, -212 },
		{ -51, -171 },
		{ -92, -139 },
		{ -120, -116 },
		{ -145, -82 },
		{ -173, -45 },
		{ -214, -27 },
		{ -271, -21 },
		{ -356, -21 },
	}),
	width = 40,
	-- Everyone wades at this share of their speed unless on a crossing.
	speedFactor = 0.6,
	-- Water depth above the ground. Shallow, so plants wade, not swim.
	depth = 1.6,
	-- Roblox terrain water (moving waves, reflections). Set to false to use a
	-- plain see-through blue part instead.
	terrainWater = true,
	waterColour = table.freeze({ 60, 130, 160 }),
	waterTransparency = 0.6,
	waterReflectance = 0.6,
	waveSize = 0.08,
	waveSpeed = 8,
	-- Colour of the plain part used when `terrainWater` is false.
	plainColour = table.freeze({ 60, 130, 200 }),
})

-- Stone moon bridge: a steep arch that plants up to `passUnderMaxLevel`
-- can walk under through the water. `x`, `z` is its middle; it lies across
-- the river.
Map.MoonBridge = table.freeze({
	x = -120,
	z = -116,
	width = 16,
	-- Length from bank to bank, and how high the middle of the deck is.
	span = 64,
	rise = 15,
	thickness = 2,
	segments = 20,
	parapetHeight = 2.5,
	parapetThickness = 1,
	passUnderMaxLevel = 4,
	-- Studs to spare above a level 4 plant's nominal height (its head ball
	-- sticks up past it), checked a little off the middle too.
	headroom = 3,
	colour = table.freeze({ 150, 150, 140 }),
	parapetColour = table.freeze({ 130, 130, 122 }),
})

-- Rope bridge from the marsh to the Hills. It sways a little (client side,
-- for looks).
Map.RopeBridge = table.freeze({
	x = -21,
	z = -302,
	width = 10,
	length = 60,
	-- Deck height at the ends and how far it sags in the middle (keep the
	-- middle above `River.depth`).
	endHeight = 3,
	sag = 0.8,
	plankLength = 1.2,
	plankGap = 0.25,
	plankThickness = 0.4,
	postHeight = 8,
	postDiameter = 1.6,
	ropeHeight = 3.5,
	ropeThickness = 0.35,
	rampLength = 5,
	-- Sway: the deck swings like a cradle hanging from the tops of the posts,
	-- this many degrees each way, once every `swaySeconds`.
	swayDegrees = 3,
	swaySeconds = 4,
	plankColour = table.freeze({ 140, 105, 70 }),
	postColour = table.freeze({ 115, 85, 55 }),
	ropeColour = table.freeze({ 175, 150, 105 }),
})

-- Rock ford near the left edge: a wide band of flat rocks across the river,
-- close enough together to walk over like a bridge.
Map.Ford = table.freeze({
	x = -300,
	z = -21,
	-- Rocks in each row across the river, and rows along the river.
	rocksAcross = 10,
	rows = 2,
	spacing = 5,
	-- Rock sizes, and top heights above the ground (above `River.depth`).
	minSize = 6.5,
	maxSize = 8.5,
	minTop = 1.9,
	maxTop = 2.5,
	-- The first and last rock in each row are lower, as a step up from the bank.
	bankTop = 1.2,
	-- Rocks tip this many degrees at most, so they don't look laid flat.
	tiltDegrees = 4,
	-- Small rocks scattered in the water near the ford, for looks.
	looseRocks = 26,
	looseMinSize = 1.5,
	looseMaxSize = 4,
	-- How far up and down the river from the ford the loose rocks spread.
	looseSpread = 22,
	-- Splashes: white spray on the upstream side of this many ford rocks.
	splashRocks = 8,
	splashRate = 14,
	splashSpeed = 6,
	splashLifetime = 0.7,
	splashSize = 1.4,
	colours = table.freeze({
		table.freeze({ 120, 115, 105 }),
		table.freeze({ 105, 100, 95 }),
		table.freeze({ 135, 125, 110 }),
		table.freeze({ 95, 95, 90 }),
		table.freeze({ 125, 120, 115 }),
	}),
})

-- Path of separate stone pavers from the moon bridge to the gate.
Map.Path = table.freeze({
	centreLine = points({
		{ -140, -141 },
		{ -165, -155 },
		{ -182, -175 },
		{ -202, -216 },
		{ -214, -257 },
		{ -222, -298 },
		{ -228, -346 },
	}),
	width = 22,
	paverSize = 4.2,
	paverGap = 1,
	paverThickness = 0.3,
	-- Pavers turn up to this many degrees either way, and sit up to this far
	-- off the grid, so the path looks laid by hand.
	paverTurnDegrees = 8,
	paverJitter = 0.4,
	colours = table.freeze({
		table.freeze({ 205, 195, 165 }),
		table.freeze({ 190, 180, 150 }),
		table.freeze({ 215, 205, 180 }),
	}),
})

-- Decorative iron gate in the top wall at the end of the path. It does not
-- open. Black iron between cream pillars, with lamps on top.
Map.Gate = table.freeze({
	x = -228,
	-- Total width, and the small side gate's share of it.
	-- Side gate, pillar, big double gate, pillar, side gate, with pillars at
	-- both ends.
	width = 62,
	sideGateWidth = 10,
	height = 12,
	pillarSize = 4,
	pillarHeight = 14,
	barSpacing = 1.2,
	barThickness = 0.35,
	-- How much the top rail of the big gate arches up in the middle.
	archRise = 2,
	lampBrightness = 2,
	lampRange = 18,
	ironColour = table.freeze({ 25, 25, 25 }),
	pillarColour = table.freeze({ 235, 220, 190 }),
	lampColour = table.freeze({ 255, 210, 140 }),
	-- Big padlock on the middle of the double gate.
	padlockSize = 2.6,
	padlockHeight = 5,
	padlockColour = table.freeze({ 190, 150, 60 }),
})

-- Loose stone wall along the edge of the River quarter: from the gate east
-- to the river, and from the gate west to the corner and down the left edge
-- to the river. Each quarter will get its own border.
Map.StoneWall = table.freeze({
	-- Runs of wall as { fromX, fromZ, toX, toZ }, inside the edge.
	runs = table.freeze({
		table.freeze({ -197, -347.5, -44, -347.5 }),
		table.freeze({ -259, -347.5, -347.5, -347.5 }),
		table.freeze({ -347.5, -347.5, -347.5, -44 }),
	}),
	height = 4.5,
	thickness = 3,
	-- Stones on the face and top: lengths and heights vary between these.
	minStoneLength = 2.6,
	maxStoneLength = 4.4,
	minStoneHeight = 1.2,
	maxStoneHeight = 1.8,
	coreColour = table.freeze({ 95, 90, 82 }),
	colours = table.freeze({
		table.freeze({ 150, 140, 125 }),
		table.freeze({ 135, 128, 115 }),
		table.freeze({ 165, 155, 135 }),
		table.freeze({ 120, 115, 105 }),
		table.freeze({ 175, 165, 150 }),
	}),
})

-- Marsh between the path and the river: mud that slows big plants.
Map.Marsh = table.freeze({
	outline = points({
		{ -214, -350 },
		{ -42, -350 },
		{ -42, -249 },
		{ -53, -196 },
		{ -71, -175 },
		{ -108, -155 },
		{ -133, -139 },
		{ -153, -145 },
		{ -171, -167 },
		{ -193, -204 },
		{ -205, -245 },
		{ -212, -294 },
	}),
	slowFromLevel = 4,
	speedFactor = 0.8,
	colour = table.freeze({ 105, 100, 55 }),
	-- The mud is laid in strips this wide (smaller follows the outline more
	-- closely but uses more parts).
	stripWidth = 4,
	-- Reed clumps for looks (no collision).
	reedClumps = 26,
	reedColour = table.freeze({ 110, 130, 60 }),
	cattailColour = table.freeze({ 100, 65, 40 }),
})

-- Lily pads on the marsh. Landing on one springs a plant up for a frog hop:
-- up to `hopHeight` studs, steering at `hopSpeed` studs per second for
-- `hopSeconds`. The map has `extraPadsPer` more pads round each guide
-- position (placed by a fixed seed, so every server matches).
Map.LilyPads = table.freeze({
	positions = points({
		{ -175, -335 },
		{ -146, -326 },
		{ -94, -323 },
		{ -59, -324 },
		{ -206, -306 },
		{ -180, -313 },
		{ -161, -301 },
		{ -135, -305 },
		{ -115, -313 },
		{ -98, -301 },
		{ -73, -306 },
		{ -117, -290 },
		{ -191, -281 },
		{ -171, -273 },
		{ -146, -282 },
		{ -91, -278 },
		{ -69, -280 },
		{ -125, -197 },
		{ -144, -181 },
		{ -113, -181 },
		{ -91, -190 },
		{ -126, -164 },
	}),
	size = 6,
	-- Each pad is up to this share bigger or smaller.
	sizeVariation = 0.12,
	thickness = 0.5,
	-- The classic cut: a wedge from the edge to the middle.
	notchDegrees = 40,
	colour = table.freeze({ 80, 165, 70 }),
	rimColour = table.freeze({ 55, 120, 50 }),
	extraPadsPer = 2,
	extraMinDistance = 7,
	extraMaxDistance = 13,
	layoutSeed = 7,
	-- White water lilies (decoration only), one per guide position, sitting
	-- on pads.
	lilyFlowers = 22,
	petalColour = table.freeze({ 250, 250, 245 }),
	petalTipColour = table.freeze({ 245, 215, 225 }),
	flowerCentreColour = table.freeze({ 250, 205, 60 }),
	hopHeight = 10.3,
	hopSeconds = 0.75,
	hopSpeed = 28,
})

-- Grass to hide in. Plants up to `hideMaxLevel` can't be seen by other
-- players inside it (their name tag still shows). Attacking reveals the
-- attacker for `revealSeconds`.
Map.HidingGrass = table.freeze({
	circles = table.freeze({
		table.freeze({ x = -292, z = -288, radius = 43 }),
		table.freeze({ x = -249, z = -115, radius = 43 }),
	}),
	hideMaxLevel = 3,
	revealSeconds = 3,
	height = 7,
	-- How see-through your own plant looks to you while hidden.
	ownTransparency = 0.5,
	-- How often each client checks who is hiding (seconds).
	checkSeconds = 0.2,
	tuftSize = 7,
	tuftSpacing = 6,
	colour = table.freeze({ 170, 200, 90 }),
})

-- Creature spawns in the River quarter: native creatures listed here spawn
-- (and wander) only in that area; every other creature keeps out of the
-- water and the marsh.
Map.CreatureAreas = table.freeze({
	blowfish = "Water",
	toad = "Marsh",
})

-- Caves in the Hills: tunnels through hills whose ceiling only lets
-- levels 1 to 3 through (see `Config/Plants.luau` for plant heights).
Map.Caves = table.freeze({
	clearance = 7,
	width = 12,
	-- Each cave: centre X, centre Z, length along X, hill height.
	list = table.freeze({
		table.freeze({ x = 200, z = -150, length = 90, hillHeight = 30 }),
		table.freeze({ x = 260, z = -280, length = 70, hillHeight = 24 }),
	}),
	-- Plain hills with no tunnel: centre X, centre Z, size, height.
	hills = table.freeze({
		table.freeze({ x = 120, z = -260, size = 60, height = 18 }),
		table.freeze({ x = 300, z = -110, size = 50, height = 14 }),
	}),
})

-- Forest: trees and hollow logs that only levels 1 and 2 fit through.
Map.Forest = table.freeze({
	trees = 70,
	logs = table.freeze({
		table.freeze({ x = -150, z = 150, length = 40 }),
		table.freeze({ x = -260, z = 260, length = 50 }),
		table.freeze({ x = -240, z = 110, length = 36 }),
	}),
	logClearance = 4.5,
})

-- Grassland: tall grass to hide in, and cow fields.
Map.Grassland = table.freeze({
	grassPatches = 14,
	cowFields = table.freeze({
		table.freeze({ x = 180, z = 180, size = 90 }),
		table.freeze({ x = 280, z = 90, size = 60 }),
	}),
})

-- Keep spawned things this far from the map edge and the field edge.
Map.edgeMargin = 12

return table.freeze(Map)
