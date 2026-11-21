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

	t.test("swamp slows only big plants; the river slows everyone off the bridges", function()
		local swamp = Map.Swamp
		local sx, sz = (swamp.minX + swamp.maxX) / 2, (swamp.minZ + swamp.maxZ) / 2
		t.expectEqual(MapRules.speedFactor(Map, 3, sx, sz, false), 1)
		t.expectEqual(MapRules.speedFactor(Map, 4, sx, sz, false), swamp.speedFactor)
		t.expectEqual(MapRules.speedFactor(Map, 4, sx, sz, true), 1, "lily pad or bridge")
		local river = Map.River
		local rx, rz = (river.minX + river.maxX) / 2, (river.minZ + river.maxZ) / 2
		t.expectEqual(MapRules.speedFactor(Map, 1, rx, rz, false), river.speedFactor)
	end)

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
