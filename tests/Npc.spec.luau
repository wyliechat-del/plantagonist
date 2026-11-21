local Npc = require("../src/shared/Config/Npc")
local NpcRules = require("../src/shared/Rules/Npc")

local me = { level = 3, x = 0, z = 0 }

return function(t)
	t.test("flees much bigger plants first", function()
		local action = NpcRules.decide(Npc, me, {
			{ key = "big", level = 5, x = 20, z = 0 },
			{ key = "small", level = 1, x = 5, z = 0 },
		}, {})
		t.expectEqual(action.kind, "flee")
		t.expectEqual(action.key, "big")
	end)

	t.test("hunts smaller plants, then eats creatures, then wanders", function()
		local hunt = NpcRules.decide(Npc, me, { { key = "small", level = 2, x = 5, z = 0 } }, {
			{ key = "bug", x = 1, z = 0 },
		})
		t.expectEqual(hunt.kind, "hunt")
		local eat = NpcRules.decide(Npc, me, { { key = "same", level = 3, x = 5, z = 0 } }, {
			{ key = "far", x = 30, z = 0 },
			{ key = "near", x = 3, z = 0 },
		})
		t.expectEqual(eat.kind, "eat")
		t.expectEqual(eat.key, "near")
		t.expectEqual(NpcRules.decide(Npc, me, {}, {}).kind, "wander")
	end)
end
