local Slots = require("../src/shared/Rules/Slots")

return function(t)
	t.test("fills free slots first", function()
		local slots = Slots.new(2, 0)
		t.expectEqual((Slots.add(slots, "attack", "spider")), 1)
		t.expectEqual((Slots.add(slots, "attack", "spider")), 2, "same power up can fill two slots")
		t.expectEqual(Slots.count(slots), 2)
	end)

	t.test("when full, the newest replaces the oldest", function()
		local slots = Slots.new(2, 0)
		Slots.add(slots, "attack", "spider")
		Slots.add(slots, "attack", "wasp")
		local index, replaced = Slots.add(slots, "attack", "eel")
		t.expectEqual(index, 1)
		t.expectEqual(replaced, "spider")
		index, replaced = Slots.add(slots, "attack", "bat")
		t.expectEqual(index, 2)
		t.expectEqual(replaced, "wasp")
	end)

	t.test("no defence slot means the power up is not kept", function()
		local slots = Slots.new(1, 0)
		t.expectEqual(Slots.add(slots, "defence", "toad"), nil)
		t.expectEqual(Slots.count(slots), 0)
	end)

	t.test("take empties a slot", function()
		local slots = Slots.new(1, 1)
		Slots.add(slots, "defence", "snail")
		t.expectEqual(Slots.take(slots, "defence", 1), "snail")
		t.expectEqual(Slots.take(slots, "defence", 1), nil)
	end)

	t.test("oldest and latest across slot types", function()
		local slots = Slots.new(2, 1)
		Slots.add(slots, "defence", "toad")
		Slots.add(slots, "attack", "spider")
		Slots.add(slots, "attack", "eel")
		local slotType, index = Slots.oldest(slots)
		t.expectEqual(slotType, "defence")
		t.expectEqual(index, 1)
		t.expectEqual(Slots.latestAttack(slots), "eel")
	end)

	t.test("findDefence picks the oldest match", function()
		local slots = Slots.new(0, 2)
		Slots.add(slots, "defence", "toad")
		Slots.add(slots, "defence", "snail")
		t.expectEqual(
			Slots.findDefence(slots, function(id)
				return id == "snail"
			end),
			2
		)
		t.expectEqual(
			Slots.findDefence(slots, function()
				return false
			end),
			nil
		)
	end)

	t.test("shrinking pops the lost slots' power ups", function()
		local slots = Slots.new(3, 1) -- level 4
		Slots.add(slots, "attack", "spider")
		Slots.add(slots, "attack", "wasp")
		Slots.add(slots, "attack", "eel")
		Slots.add(slots, "defence", "toad")
		local popped = Slots.resize(slots, 2, 1) -- down to level 3
		t.expectEqual(#popped, 1)
		t.expectEqual(popped[1], "eel")
		popped = Slots.resize(slots, 2, 0) -- down to level 2
		t.expectEqual(popped[1], "toad")
		Slots.resize(slots, 3, 2)
		t.expectEqual(#slots.attack, 3)
		t.expectEqual(#slots.defence, 2)
	end)

	t.test("a boost rides on the oldest matching slot and goes when it's used", function()
		local slots = Slots.new(3, 0)
		Slots.add(slots, "attack", "eel")
		Slots.add(slots, "attack", "spider")
		Slots.add(slots, "attack", "wasp")
		local function venom(id)
			return id == "spider" or id == "wasp"
		end
		t.expectEqual(Slots.addBoost(slots, "bee", venom), 2)
		t.expectEqual(Slots.addBoost(slots, "bee", venom), 3, "second bee on the next venom slot")
		t.expectEqual(Slots.addBoost(slots, "bee", venom), nil, "no venom slot left")
		t.expectEqual(Slots.takeBoost(slots, 2), "bee")
		t.expectEqual(Slots.takeBoost(slots, 2), nil)
		Slots.take(slots, "attack", 3)
		t.expectEqual(slots.attack[3].boost, nil, "emptying a slot loses its boost")
	end)
end
