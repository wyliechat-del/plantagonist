local Steering = require("../src/shared/Rules/Steering")

return function(t)
	t.test("moves towards a target and arrives", function()
		local x, z, arrived = Steering.moveTowards(0, 0, 10, 0, 4)
		t.expectEqual(x, 4)
		t.expectEqual(z, 0)
		t.expect(not arrived)
		x, z, arrived = Steering.moveTowards(8, 0, 10, 0, 4)
		t.expectEqual(x, 10)
		t.expect(arrived)
	end)

	t.test("flees from the nearest threat only when close", function()
		local dx, dz = Steering.fleeDirection(0, 0, { { x = 5, z = 0 }, { x = 0, z = 9 } }, 10)
		t.expectEqual(dx, -1)
		t.expectEqual(dz, 0)
		local none = Steering.fleeDirection(0, 0, { { x = 50, z = 0 } }, 10)
		t.expectEqual(none, nil)
	end)

	t.test("wander targets stay within the radius", function()
		local values = { 0.25, 1 - 1e-9 }
		local index = 0
		local function random()
			index += 1
			return values[(index - 1) % 2 + 1]
		end
		local x, z = Steering.wanderTarget(0, 0, 10, random)
		t.expect(math.sqrt(x * x + z * z) <= 10.0001)
	end)
end
