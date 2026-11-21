local Levels = require("../src/shared/Config/Levels")
local Rings = require("../src/shared/Config/Rings")
local Growth = require("../src/shared/Rules/Growth")

return function(t)
	t.test("ring ranges match the design", function()
		local ranges = { { 1, 3 }, { 4, 9 }, { 10, 19 }, { 20, 35 }, { 36, 56 }, { 57, 79 } }
		for level, range in ranges do
			t.expectEqual(
				Growth.levelFor(Levels.list, range[1]),
				level,
				`first ring of level {level}`
			)
			t.expectEqual(
				Growth.levelFor(Levels.list, range[2]),
				level,
				`last ring of level {level}`
			)
		end
		t.expectEqual(Growth.levelFor(Levels.list, 80), 6, "80 rings is still level 6 until rooted")
		t.expectEqual(Growth.levelFor(Levels.list, 0), 1)
	end)

	t.test("drop floor is one below the level's first ring", function()
		t.expectEqual(Growth.dropFloor(Levels.list, 1), 0)
		t.expectEqual(Growth.dropFloor(Levels.list, 2), 3)
		t.expectEqual(Growth.dropFloor(Levels.list, 6), 56)
	end)

	t.test("speed in studs per second", function()
		t.expectEqual(Growth.studsPerSecond(Levels.list, Levels.studsPerSpeedUnit, 1), 16.8)
		t.expectEqual(Growth.studsPerSecond(Levels.list, Levels.studsPerSpeedUnit, 5), 7)
		t.expectEqual(Growth.studsPerSecond(Levels.list, Levels.studsPerSpeedUnit, 6), 6)
	end)

	t.test("rings stay between 0 and the root cap", function()
		t.expectEqual(Growth.addRings(78, 5, Levels.rootRings), 80)
		t.expectEqual(Growth.addRings(2, -5, Levels.rootRings), 0)
		t.expect(Growth.canRoot(80, Levels.rootRings))
		t.expect(not Growth.canRoot(79, Levels.rootRings))
	end)

	t.test("creature rings by size, or a roll when fertilised", function()
		local function roll(_min, max)
			return max
		end
		t.expectEqual(Growth.creatureRings(Rings, "Small", false, roll), Rings.bySize.Small)
		t.expectEqual(Growth.creatureRings(Rings, "Large", false, roll), Rings.bySize.Large)
		t.expectEqual(Growth.creatureRings(Rings, "Small", true, roll), Rings.fertilisedMax)
	end)

	t.test("flies stop paying at 4 rings", function()
		t.expectEqual(Growth.flyRings(Rings, 3), 1)
		t.expectEqual(Growth.flyRings(Rings, 4), 0)
	end)

	t.test("rain pays per level", function()
		t.expectEqual(Growth.rainRings(Rings, 4), 4)
	end)
end
