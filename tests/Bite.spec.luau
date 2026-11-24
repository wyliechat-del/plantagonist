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
	-- Bites for a plant at the top of each level, with the ring ranges from
	-- playtest 2 (rooting at 80).
	t.test("bites needed to eat a plant at the top of each level", function()
		local tops = { 3, 9, 19, 35, 56, 79 }
		local expected = {
			{ 3, 9, 19, 35, 56, 79 },
			{ 2, 5, 10, 18, 29, 41 },
			{ 1, 3, 7, 13, 20, 28 },
			{ 1, 3, 6, 10, 16, 22 },
			{ 1, 3, 5, 9, 14, 19 },
			{ 1, 2, 4, 7, 11, 15 },
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
		local result = Bite.resolve(Combat, 6, 58, Growth.dropFloor(Levels.list, 6))
		t.expectEqual(result.taken, 2)
		t.expectEqual(result.victimRings, 56)
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

	t.test("levels 4 to 6 roar first and lift smaller plants", function()
		t.expect(not Bite.roars(Combat, 3))
		t.expect(Bite.roars(Combat, 4))
		t.expect(Bite.lifts(Combat, 5, 2))
		t.expect(not Bite.lifts(Combat, 5, 5), "same size is not lifted")
		t.expect(not Bite.lifts(Combat, 3, 1), "small plants toss without lifting")
	end)

	t.test("levels 4 to 6 stagger when hit, unless they are lifted", function()
		t.expect(Bite.staggers(Combat, 2, 4), "a small plant staggers a big one")
		t.expect(Bite.staggers(Combat, 4, 4))
		t.expect(not Bite.staggers(Combat, 6, 4), "lifted instead")
		t.expect(not Bite.staggers(Combat, 1, 3), "small plants don't stagger")
	end)

	t.test("cooldown and escape moment block bites", function()
		t.expect(Bite.canBite(Combat, 10, nil, nil))
		t.expect(not Bite.canBite(Combat, 10.5, 10, nil), "inside cooldown")
		t.expect(Bite.canBite(Combat, 10.8, 10, nil), "cooldown over")
		local safeUntil = Bite.escapeUntil(Combat, 20)
		t.expect(not Bite.canBite(Combat, 21, nil, safeUntil), "escape moment")
		t.expect(Bite.canBite(Combat, 21.5, nil, safeUntil))
	end)

	t.test("range and reach are the same for every level", function()
		t.expectEqual(Bite.rangeStuds(Combat, 1), 50)
		t.expectEqual(Bite.rangeStuds(Combat, 6), 50)
		t.expectEqual(Bite.reachStuds(Combat, 1), 9)
		t.expectEqual(Bite.reachStuds(Combat, 6), 9)
		t.expectEqual(Bite.flightSeconds(Combat, 40), 2)
	end)
end
