local Map = require("../src/shared/Config/Map")
local Plants = require("../src/shared/Config/Plants")
local MapRules = require("../src/shared/Rules/Map")

local CHARACTER_HEIGHT = 5 -- a scale 1 Roblox character, roughly

return function(t)
	t.test("territories are the four quarters, the field is the middle", function()
		t.expectEqual(MapRules.territoryAt(Map, 200, 200), "Grassland")
		t.expectEqual(MapRules.territoryAt(Map, -200, 200), "Forest")
		t.expectEqual(MapRules.territoryAt(Map, -200, -200), "River")
		t.expectEqual(MapRules.territoryAt(Map, 200, -200), "Hills")
		t.expectEqual(MapRules.territoryAt(Map, 10, -10), "Field")
	end)

	t.test("only levels 1 and 2 may be in the field", function()
		t.expect(MapRules.canBeInField(Map, 2))
		t.expect(not MapRules.canBeInField(Map, 3))
		local x, z = MapRules.pushOut(Map, 30, 40)
		local distance = MapRules.distanceFromCentre(x, z)
		t.expectEqual(math.floor(distance + 0.5), Map.Field.radius + Map.Field.pushOutMargin)
	end)

	t.test("12 exits, 3 per territory", function()
		local angles = MapRules.exitAngles(Map)
		t.expectEqual(#angles, 12)
		t.expect(MapRules.isExitAngle(Map, 45))
		t.expect(MapRules.isExitAngle(Map, 45 + 360))
		t.expect(not MapRules.isExitAngle(Map, 0))
	end)

	t.test("river slows everyone; marsh slows only levels 4 to 6; crossings don't slow", function()
		local rx, rz = Map.River.centreLine[5][1], Map.River.centreLine[5][2]
		t.expectEqual(MapRules.areaAt(Map, rx, rz), "Water")
		t.expectEqual(MapRules.speedFactor(Map, 1, rx, rz, false), Map.River.speedFactor)
		t.expectEqual(MapRules.speedFactor(Map, 6, rx, rz, true), 1, "on a bridge")
		local pad = Map.LilyPads.positions[1]
		t.expectEqual(MapRules.areaAt(Map, pad[1], pad[2]), "Marsh")
		t.expectEqual(MapRules.speedFactor(Map, 3, pad[1], pad[2], false), 1)
		t.expectEqual(MapRules.speedFactor(Map, 4, pad[1], pad[2], false), Map.Marsh.speedFactor)
		t.expectEqual(MapRules.speedFactor(Map, 6, pad[1], pad[2], true), 1, "on a lily pad")
		t.expectEqual(MapRules.speedFactor(Map, 6, -300, -200, false), 1, "green land")
		local path = Map.Path.centreLine[4]
		t.expectEqual(MapRules.speedFactor(Map, 6, path[1], path[2], false), 1, "the path")
	end)

	t.test("all lily pads sit on the marsh, and the river stays in the River quarter", function()
		for _, pad in Map.LilyPads.positions do
			t.expect(MapRules.inMarsh(Map, pad[1], pad[2]), `pad at {pad[1]}, {pad[2]}`)
		end
		for _, point in MapRules.pointsAlong(Map.River.centreLine, 5, 0) do
			local x, z = point[1], point[2]
			if math.abs(x) < Map.halfSize and math.abs(z) < Map.halfSize then
				t.expect(
					x + Map.River.width / 2 <= 0 and z + Map.River.width / 2 <= 0,
					`river at {x}, {z}`
				)
				local clear = MapRules.distanceFromCentre(x, z) - Map.River.width / 2
				t.expect(clear > Map.Field.radius + 10, "river clear of the safe field")
			end
		end
	end)

	t.test("crossings sit on the river and the path starts at the moon bridge", function()
		for _, crossing in { Map.MoonBridge, Map.RopeBridge, Map.Ford } do
			t.expect(MapRules.inRiver(Map, crossing.x, crossing.z), "crossing over water")
		end
		local _, dx, dz =
			MapRules.closestOnLine(Map.River.centreLine, Map.MoonBridge.x, Map.MoonBridge.z)
		local first = Map.Path.centreLine[1]
		local ex, ez =
			Map.MoonBridge.x - dz * Map.MoonBridge.span / 2,
			Map.MoonBridge.z + dx * Map.MoonBridge.span / 2
		local fx, fz =
			Map.MoonBridge.x + dz * Map.MoonBridge.span / 2,
			Map.MoonBridge.z - dx * Map.MoonBridge.span / 2
		local nearest = math.min(
			math.sqrt((ex - first[1]) ^ 2 + (ez - first[2]) ^ 2),
			math.sqrt((fx - first[1]) ^ 2 + (fz - first[2]) ^ 2)
		)
		t.expect(nearest < 6, `path starts {nearest} studs from a bridge end`)
		local last = Map.Path.centreLine[#Map.Path.centreLine]
		t.expect(math.abs(last[1] - Map.Gate.x) < 1, "path ends at the gate")
	end)

	t.test("moon bridge: levels 1 to 4 fit under the middle with room to spare", function()
		local bridge = Map.MoonBridge
		local height = CHARACTER_HEIGHT * Plants.scaleByLevel[bridge.passUnderMaxLevel]
		local radius = Plants.radiusAtScale1 * Plants.scaleByLevel[bridge.passUnderMaxLevel]
		for _, offset in { 0, radius * 2 } do
			local underside = MapRules.moonBridgeHeight(Map, offset) - bridge.thickness
			t.expect(
				height + bridge.headroom < underside,
				`level 4 fits {offset} studs off the middle`
			)
		end
		t.expectEqual(MapRules.moonBridgeHeight(Map, bridge.span / 2), 0, "meets the bank")
		-- Not steeper than a plant can walk.
		local slope = 4 * bridge.rise / bridge.span
		t.expect(math.deg(math.atan(slope)) < 50, "walkable slope")
	end)

	t.test("rope bridge and ford rocks stay above the water", function()
		t.expect(MapRules.ropeBridgeHeight(Map, 0) > Map.River.depth, "rope bridge middle")
		t.expect(Map.Ford.minTop > Map.River.depth, "ford rocks")
	end)

	t.test("frog hop: launch speed reaches the hop height", function()
		local gravity = 196.2
		local speed = MapRules.hopLaunchSpeed(gravity, Map.LilyPads.hopHeight)
		t.expect(math.abs(speed * speed / (2 * gravity) - Map.LilyPads.hopHeight) < 1e-6)
	end)

	t.test("three times the lily pads, all on the marsh and not overlapping", function()
		local pads = MapRules.lilyPadLayout(Map)
		t.expectEqual(#pads, #Map.LilyPads.positions * (1 + Map.LilyPads.extraPadsPer))
		local minGap = Map.LilyPads.size * (1 + Map.LilyPads.sizeVariation)
		for i, pad in pads do
			t.expect(MapRules.inMarsh(Map, pad[1], pad[2]), "on the marsh")
			for j = i + 1, #pads do
				local other = pads[j]
				t.expect(
					math.sqrt((pad[1] - other[1]) ^ 2 + (pad[2] - other[2]) ^ 2) >= minGap,
					"no overlap"
				)
			end
		end
		t.expectEqual(MapRules.lilyPadLayout(Map)[30][1], pads[30][1], "same layout every time")
	end)

	t.test("hiding grass hides levels 1 to 3 until they attack", function()
		local circle = Map.HidingGrass.circles[1]
		t.expect(MapRules.hiddenInGrass(Map, 3, circle.x, circle.z, 10, 0))
		t.expect(not MapRules.hiddenInGrass(Map, 4, circle.x, circle.z, 10, 0), "too big")
		t.expect(not MapRules.hiddenInGrass(Map, 1, circle.x, circle.z, 10, 12), "just attacked")
		t.expect(not MapRules.hiddenInGrass(Map, 1, 0, 0, 10, 0), "not in grass")
	end)

	t.test(
		"native blowfish spawn in the river, native toads in the marsh, others on land",
		function()
			t.expectEqual(MapRules.creatureArea(Map, "blowfish", true), "Water")
			t.expectEqual(MapRules.creatureArea(Map, "toad", true), "Marsh")
			t.expectEqual(MapRules.creatureArea(Map, "toad", false), "Land")
			t.expectEqual(MapRules.creatureArea(Map, "eel", true), "Land")
			local seed = 1
			local function random()
				seed = (seed * 16807 + 12345) % 2147483647
				return seed / 2147483647
			end
			for _, area in { "Water", "Marsh", "Land" } do
				for _ = 1, 20 do
					local x, z = MapRules.randomPointInArea(Map, "River", area, random)
					t.expectEqual(MapRules.areaAt(Map, x, z), area)
					t.expectEqual(MapRules.territoryAt(Map, x, z), "River")
				end
			end
		end
	)

	t.test("random points stay in their territory", function()
		local seed = 0
		local function random()
			seed = (seed * 16807 + 12345) % 2147483647
			return seed / 2147483647
		end
		for _, name in { "Grassland", "Forest", "River", "Hills" } do
			for _ = 1, 50 do
				local x, z = MapRules.randomPointIn(Map, name, random)
				t.expectEqual(MapRules.territoryAt(Map, x, z), name)
			end
		end
		local x, z = MapRules.clampToTerritory(Map, "Hills", -50, 900)
		t.expectEqual(MapRules.territoryAt(Map, x, z), "Hills")
	end)

	t.test("caves fit levels 1 to 3, logs fit levels 1 and 2", function()
		local function height(level)
			return CHARACTER_HEIGHT * Plants.scaleByLevel[level]
		end
		t.expect(height(3) < Map.Caves.clearance, "level 3 fits a cave")
		t.expect(height(4) > Map.Caves.clearance, "level 4 doesn't")
		t.expect(height(2) < Map.Forest.logClearance, "level 2 fits a log")
		t.expect(height(3) > Map.Forest.logClearance, "level 3 doesn't")
	end)

	t.test("spawn mix: mostly native, some neighbours, a few from opposite", function()
		local neighbours, opposite = MapRules.relatives(Map, "Grassland")
		t.expectEqual(#neighbours, 2)
		t.expectEqual(opposite, "River")
		local mix = { native = 0.7, neighbour = 0.2, opposite = 0.1 }
		local function fixed(value)
			return function()
				return value
			end
		end
		t.expectEqual(MapRules.spawnSource(Map, "Grassland", mix, fixed(0.5)), "Grassland")
		local neighbour = MapRules.spawnSource(Map, "Grassland", mix, fixed(0.8))
		t.expect(neighbour == "Forest" or neighbour == "Hills", "neighbour")
		t.expectEqual(MapRules.spawnSource(Map, "Grassland", mix, fixed(0.95)), "River")
	end)
end
