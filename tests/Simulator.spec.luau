local Assumptions = require("../sim/Assumptions")
local Random = require("../sim/Random")
local Simulator = require("../sim/Simulator")

return function(t)
	t.test("random numbers repeat for the same seed and stay in range", function()
		local a, b = Random.new(42), Random.new(42)
		for _ = 1, 100 do
			local value = a:int(2, 6)
			t.expectEqual(value, b:int(2, 6))
			t.expect(value >= 2 and value <= 6, "in range")
		end
	end)

	t.test("a session starts at level 1 and reaches levels in order", function()
		local result = Simulator.session(Assumptions.profiles[1], 600, Random.new(1))
		t.expectEqual(result.reachedAt[1], 0)
		for level = 2, Simulator.rootLevel do
			local at = result.reachedAt[level]
			if at then
				t.expect(result.reachedAt[level - 1] ~= nil, `level {level - 1} reached first`)
				t.expect(at >= result.reachedAt[level - 1], `level {level} after level {level - 1}`)
			end
		end
	end)

	t.test("runs are repeatable", function()
		local profile = Assumptions.profiles[1]
		local first = Simulator.run(profile, 50, 600, 7)
		local second = Simulator.run(profile, 50, 600, 7)
		t.expectEqual(first.levels[4].median, second.levels[4].median)
	end)
end
