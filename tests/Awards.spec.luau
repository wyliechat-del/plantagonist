local Awards = require("../src/shared/Config/Awards")
local PowerUps = require("../src/shared/Config/PowerUps")
local AwardRules = require("../src/shared/Rules/Awards")

return function(t)
	t.test("first bite comes from eating a creature, once", function()
		local progress = AwardRules.newProgress()
		AwardRules.recordEaten(progress, "spider")
		local new = AwardRules.collectNew(Awards, PowerUps, progress)
		t.expectEqual(#new, 1)
		t.expectEqual(new[1].id, "FirstBite")
		t.expectEqual(#AwardRules.collectNew(Awards, PowerUps, progress), 0, "not earned twice")
	end)

	t.test("family awards need every creature in the family", function()
		local progress = AwardRules.newProgress()
		for _, id in { "spider", "wasp", "toad" } do
			AwardRules.recordEaten(progress, id)
		end
		AwardRules.collectNew(Awards, PowerUps, progress)
		t.expect(not progress.earned.VenomCollector)
		AwardRules.recordEaten(progress, "bee")
		AwardRules.collectNew(Awards, PowerUps, progress)
		t.expect(progress.earned.VenomCollector)
	end)

	t.test("show off needs all four special moves used", function()
		local progress = AwardRules.newProgress()
		for _, id in { "bat", "blowfish", "centipede", "stickInsect" } do
			AwardRules.recordUsed(progress, id)
		end
		AwardRules.collectNew(Awards, PowerUps, progress)
		t.expect(progress.earned.ShowOff)
	end)

	t.test("counters", function()
		local progress = AwardRules.newProgress()
		AwardRules.addCount(progress, "rainCaught", 9)
		AwardRules.collectNew(Awards, PowerUps, progress)
		t.expect(not progress.earned.RainDancer)
		AwardRules.addCount(progress, "rainCaught")
		AwardRules.collectNew(Awards, PowerUps, progress)
		t.expect(progress.earned.RainDancer)
	end)

	t.test("repair fills in old or broken saves", function()
		local repaired = AwardRules.repair({ counters = { rooted = 2 } })
		t.expectEqual(repaired.counters.rooted, 2)
		t.expectEqual(type(repaired.eaten), "table")
		t.expectEqual(type(AwardRules.repair(nil).earned), "table")
	end)

	t.test("every award has a valid kind and target", function()
		for _, award in Awards.list do
			local ok = pcall(AwardRules.isMet, PowerUps, award, AwardRules.newProgress())
			t.expect(ok, `{award.id} checks without error`)
		end
	end)
end
