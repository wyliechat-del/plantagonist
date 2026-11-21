--[[
	Power up families and the creatures that carry them.

	Each creature has:
	- `family`: which family it belongs to (key of `families`).
	- `kind`: "melee" or "range" (attack slot, hits a target), "special"
	  (attack slot, acts on yourself) or "defence" (defence slot, automatic).
	- `territory`: "Grassland", "Hills", "River" or "Forest".
	- `size`: "Small", "Medium" or "Large" (rings are in `Config/Rings.luau`).
	- `effect` (optional): replaces the family effect for this creature.

	Durations that say "PerLevel" are multiplied by the user's level.
	Colours are { red, green, blue } from 0 to 255.
]]

local PowerUps = {}

PowerUps.families = table.freeze({
	Venom = table.freeze({
		colour = table.freeze({ 150, 70, 200 }),
		-- Target can't use power ups for this long per attacker level.
		effect = table.freeze({ lockoutSecondsPerLevel = 0.5 }),
	}),
	BiteAndSlash = table.freeze({
		colour = table.freeze({ 210, 50, 50 }),
		-- Multiplies the bite damage. Damage still stops at a level drop.
		effect = table.freeze({ damageMultiplier = 2 }),
	}),
	Strangle = table.freeze({
		colour = table.freeze({ 240, 140, 30 }),
		-- Target can't move for this long per attacker level.
		effect = table.freeze({ holdSecondsPerLevel = 0.5 }),
	}),
	SpecialMove = table.freeze({
		colour = table.freeze({ 240, 210, 40 }),
		effect = table.freeze({}),
	}),
})

PowerUps.creatures = table.freeze({
	-- Venom
	spider = table.freeze({
		family = "Venom",
		kind = "melee",
		territory = "Grassland",
		size = "Small",
	}),
	wasp = table.freeze({ family = "Venom", kind = "range", territory = "Forest", size = "Small" }),
	toad = table.freeze({
		family = "Venom",
		kind = "defence",
		territory = "River",
		size = "Medium",
	}),
	-- Bee: a venom sack sticks to the target and the venom lasts twice as long.
	bee = table.freeze({
		family = "Venom",
		kind = "melee",
		territory = "Hills",
		size = "Medium",
		effect = table.freeze({ lockoutSecondsPerLevel = 1, sticky = true }),
	}),

	-- Bite and slash
	bullAnt = table.freeze({
		family = "BiteAndSlash",
		kind = "melee",
		territory = "Hills",
		size = "Small",
	}),
	snake = table.freeze({
		family = "BiteAndSlash",
		kind = "range",
		territory = "River",
		size = "Medium",
	}),
	snail = table.freeze({
		family = "BiteAndSlash",
		kind = "defence",
		territory = "Forest",
		size = "Medium",
	}),
	-- Praying mantis: your next Bite and slash power up isn't used up, and
	-- can be used again after `reuseSeconds`.
	mantis = table.freeze({
		family = "BiteAndSlash",
		kind = "special",
		territory = "Grassland",
		size = "Medium",
		effect = table.freeze({ keepNextFamilyPowerUp = true, reuseSeconds = 0.8 }),
	}),

	-- Strangle
	eel = table.freeze({ family = "Strangle", kind = "melee", territory = "River", size = "Large" }),
	chameleon = table.freeze({
		family = "Strangle",
		kind = "range",
		territory = "Hills",
		size = "Medium",
	}),
	skunk = table.freeze({
		family = "Strangle",
		kind = "defence",
		territory = "Grassland",
		size = "Large",
	}),
	-- Bombardier beetle: acid spray removes the target's oldest power up.
	bombardierBeetle = table.freeze({
		family = "Strangle",
		kind = "range",
		territory = "Forest",
		size = "Medium",
		effect = table.freeze({ removeOldestPowerUp = true }),
	}),

	-- Special moves
	bat = table.freeze({
		family = "SpecialMove",
		kind = "special",
		territory = "Hills",
		size = "Large",
		effect = table.freeze({ flySecondsPerLevel = 1 }),
	}),
	-- Blowfish: ignore all attacks, puff into a ball and bounce away. The
	-- design gives no duration yet; 2 seconds is a placeholder.
	blowfish = table.freeze({
		family = "SpecialMove",
		kind = "special",
		territory = "River",
		size = "Large",
		effect = table.freeze({ ballSeconds = 2 }),
	}),
	centipede = table.freeze({
		family = "SpecialMove",
		kind = "special",
		territory = "Forest",
		size = "Small",
		effect = table.freeze({ speedBurst = 6, speedBurstSecondsPerLevel = 0.5 }),
	}),
	stickInsect = table.freeze({
		family = "SpecialMove",
		kind = "special",
		territory = "Grassland",
		size = "Small",
		effect = table.freeze({ invisibleSecondsPerLevel = 1 }),
	}),
})

return table.freeze(PowerUps)
