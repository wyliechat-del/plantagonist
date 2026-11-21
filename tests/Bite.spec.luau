local Combat = require("../src/shared/Config/Combat")
local Levels = require("../src/shared/Config/Levels")
local Bite = require("../src/shared/Rules/Bite")
local Growth = require("../src/shared/Rules/Growth")

-- Bites for `attacker` to eat a plant starting at `rings`.
local function bitesToEat(attacker: number, rings: number): number
	local bites = 0
	while rings > 0 do
		local floor = Growth.dropFloor(Levels.list, Growth.levelFor(Levels.list, rings))
		rings = Bite.resolve(Combat, attacker, rings, floor).victimRings
		bites += 1
	end
	return bites
end

return function(t)
	t.test("bites needed match the table in the design doc", function()
		local tops = { 3, 9, 21, 45, 69, 93 }
		local expected = {
			{ 3, 9, 21, 45, 69, 93 },
			{ 2, 5, 11, 23, 35, 47 },
			{ 1, 3, 7, 15, 23, 31 },
			{ 1, 3, 6, 12, 18, 24 },
			{ 1, 3, 6, 11, 16, 21 },
			{ 1, 2, 4, 8, 12, 16 },
		}
		for attacker, row in expected do
			for victim, bites in row do
				t.expectEqual(
					bitesToEat(attacker, tops[victim]),
					bites,
					`L{attacker} eating L{victim}`
				)
			end
		end
	end)

	t.test("damage stops at a level drop", function()
		local result = Bite.resolve(Combat, 6, 71, Growth.dropFloor(Levels.list, 6))
		t.expectEqual(result.taken, 2)
		t.expectEqual(result.victimRings, 69)
		t.expect(result.droppedLevel)
		t.expect(not result.eaten)
	end)

	t.test("bite and slash doubles damage but still stops at the drop", function()
		local result = Bite.resolve(Combat, 3, 93, 69, 2)
		t.expectEqual(result.taken, 6)
		local capped = Bite.resolve(Combat, 6, 75, 69, 2)
		t.expectEqual(capped.taken, 6)
		t.expect(capped.droppedLevel)
	end)

	t.test("half to the biter, rounded up; the rest spills as nuts", function()
		local even = Bite.resolve(Combat, 4, 40, 21)
		t.expectEqual(even.toBiter, 2)
		t.expectEqual(even.toNuts, 2)
		local peck = Bite.resolve(Combat, 1, 40, 21)
		t.expectEqual(peck.toBiter, 1)
		t.expectEqual(peck.toNuts, 0)
	end)

	t.test("bringing a plant to 0 eats it", function()
		local result = Bite.resolve(Combat, 3, 2, 0)
		t.expect(result.eaten)
		t.expect(result.droppedLevel)
		t.expectEqual(Bite.eatBonus(Combat, 6), 12)
	end)

	t.test("bigger plants chew and toss, smaller ones peck", function()
		t.expect(Bite.isChewAndToss(4, 2))
		t.expect(not Bite.isChewAndToss(2, 2))
	end)

	t.test("cooldown and escape moment block bites", function()
		t.expect(Bite.canBite(Combat, 10, nil, nil))
		t.expect(not Bite.canBite(Combat, 10.5, 10, nil), "inside cooldown")
		t.expect(Bite.canBite(Combat, 10.8, 10, nil), "cooldown over")
		local safeUntil = Bite.escapeUntil(Combat, 20)
		t.expect(not Bite.canBite(Combat, 21, nil, safeUntil), "escape moment")
		t.expect(Bite.canBite(Combat, 21.5, nil, safeUntil))
	end)

	t.test("range is 10 studs plus 5 per level", function()
		t.expectEqual(Bite.rangeStuds(Combat, 1), 15)
		t.expectEqual(Bite.rangeStuds(Combat, 6), 40)
		t.expectEqual(Bite.flightSeconds(Combat, 40), 2)
	end)
end
