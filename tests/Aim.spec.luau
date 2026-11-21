local Aim = require("../src/shared/Rules/Aim")

local origin = { x = 0, y = 0, z = 0 }
local forward = { x = 0, y = 0, z = -1 }

return function(t)
	t.test("picks the target nearest the crosshair", function()
		local candidates = {
			{ key = "left", x = -5, y = 0, z = -10, radius = 1 },
			{ key = "ahead", x = 0.5, y = 0, z = -12, radius = 1 },
		}
		local best = Aim.pick(candidates, origin, forward, origin, 20, 30)
		t.expectEqual(best and best.key, "ahead")
	end)

	t.test("skips targets out of reach or off to the side", function()
		local far = { { key = "far", x = 0, y = 0, z = -50, radius = 1 } }
		t.expectEqual(Aim.pick(far, origin, forward, origin, 20, 30), nil)
		local behind = { { key = "behind", x = 0, y = 0, z = 10, radius = 1 } }
		t.expectEqual(Aim.pick(behind, origin, forward, origin, 20, 30), nil)
	end)

	t.test("big targets count from their edge", function()
		local big = { { key = "big", x = 0, y = 0, z = -24, radius = 6 } }
		t.expectEqual((Aim.pick(big, origin, forward, origin, 20, 30) or {}).key, "big")
	end)
end
