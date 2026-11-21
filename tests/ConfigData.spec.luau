-- Checks that the Config tables are consistent with each other, so a typo in
-- a balancing change fails here instead of in a playtest.
local Levels = require("../src/shared/Config/Levels")
local PowerUps = require("../src/shared/Config/PowerUps")
local Rings = require("../src/shared/Config/Rings")

return function(t)
	t.test("levels rise in rings and fall in speed", function()
		for index = 2, #Levels.list do
			local before, after = Levels.list[index - 1], Levels.list[index]
			t.expect(after.minRings > before.minRings, `{after.name} needs more rings`)
			t.expect(after.speed <= before.speed, `{after.name} is no faster`)
			t.expect(after.attackSlots >= before.attackSlots, `{after.name} keeps its attack slots`)
			t.expect(
				after.defenceSlots >= before.defenceSlots,
				`{after.name} keeps its defence slots`
			)
		end
		t.expect(Levels.rootRings > Levels.list[#Levels.list].minRings)
	end)

	t.test("every creature has a valid family, kind, territory and size", function()
		local kinds = { melee = true, range = true, special = true, defence = true }
		local territories = { Grassland = true, Hills = true, River = true, Forest = true }
		local count = 0
		for id, creature in PowerUps.creatures do
			count += 1
			t.expect(PowerUps.families[creature.family], `{id} family`)
			t.expect(kinds[creature.kind], `{id} kind`)
			t.expect(territories[creature.territory], `{id} territory`)
			t.expect(Rings.bySize[creature.size], `{id} size`)
		end
		t.expectEqual(count, 16, "16 power ups")
	end)

	t.test("each territory has 4 creatures, one per family", function()
		local seen = {}
		for _, creature in PowerUps.creatures do
			seen[creature.territory] = seen[creature.territory] or {}
			t.expect(not seen[creature.territory][creature.family], "one per family per territory")
			seen[creature.territory][creature.family] = true
		end
	end)
end
