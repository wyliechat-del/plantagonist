local Aim = require("../src/shared/Rules/Aim")

local origin = { x = 0, y = 0, z = 0 }
local forward = { x = 0, y = 0, z = -1 }

return function(t)
	t.test("picks the target under the click", function()
		local candidates = {
			{ key = "left", x = -5, y = 0, z = -10, radius = 1 },
			{ key = "ahead", x = 0.5, y = 0, z = -12, radius = 1 },
		}
		local best = Aim.pickOnRay(candidates, origin, forward, origin, 20, 2)
		t.expectEqual(best and best.key, "ahead")
	end)

	t.test("skips targets out of reach, behind, or off the click", function()
		local far = { { key = "far", x = 0, y = 0, z = -50, radius = 1 } }
		t.expectEqual(Aim.pickOnRay(far, origin, forward, origin, 20, 2), nil)
		local behind = { { key = "behind", x = 0, y = 0, z = 10, radius = 1 } }
		t.expectEqual(Aim.pickOnRay(behind, origin, forward, origin, 20, 2), nil)
		local aside = { { key = "aside", x = 6, y = 0, z = -10, radius = 1 } }
		t.expectEqual(Aim.pickOnRay(aside, origin, forward, origin, 20, 2), nil)
	end)

	t.test("big targets count from their edge", function()
		local big = { { key = "big", x = 0, y = 0, z = -24, radius = 5 } }
		t.expect(Aim.pickOnRay(big, origin, forward, origin, 20, 2) ~= nil)
		local wide = { { key = "wide", x = 5, y = 0, z = -10, radius = 4 } }
		t.expect(Aim.pickOnRay(wide, origin, forward, origin, 20, 2) ~= nil)
	end)

	t.test("on a tie the nearer target wins", function()
		local candidates = {
			{ key = "far", x = 0, y = 0, z = -15, radius = 1 },
			{ key = "near", x = 0, y = 0, z = -5, radius = 1 },
		}
		local best = Aim.pickOnRay(candidates, origin, forward, origin, 20, 2)
		t.expectEqual(best and best.key, "near")
	end)

	t.test("nearest picks the closest target in reach", function()
		local candidates = {
			{ key = "a", x = 8, y = 0, z = 0, radius = 1 },
			{ key = "b", x = 0, y = 0, z = 4, radius = 1 },
			{ key = "c", x = 30, y = 0, z = 0, radius = 1 },
		}
		local best = Aim.nearest(candidates, origin, 10)
		t.expectEqual(best and best.key, "b")
		t.expectEqual(Aim.nearest({ candidates[3] }, origin, 10), nil)
	end)

	t.test("a miss lands within reach", function()
		local near = Aim.missPoint(origin, { x = 3, y = 1, z = 0 }, 5)
		t.expectEqual(near.x, 3)
		local far = Aim.missPoint(origin, { x = 0, y = 2, z = -20 }, 5)
		t.expectEqual(far.z, -5)
		t.expectEqual(far.y, 2)
	end)
end
