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

-- The conservatory building (glass house) in the centre.
Map.Conservatory = table.freeze({
	halfSize = 30,
	height = 22,
	doorWidth = 12,
	doorHeight = 10,
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

-- River: a slow band across the River quarter, with log bridges over it.
Map.River = table.freeze({
	minX = -350,
	maxX = -75,
	minZ = -190,
	maxZ = -160,
	-- Everyone wades at this share of their speed unless on a bridge.
	speedFactor = 0.6,
	bridgeXs = table.freeze({ -120, -230, -320 }),
	bridgeWidth = 10,
	bridgeHeight = 3,
})

-- Swamp: mud slows big plants; small plants hop across lily pads.
Map.Swamp = table.freeze({
	minX = -330,
	maxX = -110,
	minZ = -335,
	maxZ = -225,
	slowFromLevel = 4,
	speedFactor = 0.7,
	lilyPads = 30,
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
