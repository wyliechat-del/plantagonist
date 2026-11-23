--[[
	Power up families and the creatures that carry them.

	Each creature has:
	- `name`: shown to players.
	- `family`: which family it belongs to (key of `families`).
	- `kind`: "melee" or "range" (attack slot, hits a target), "special"
	  (attack slot, acts on yourself), "defence" (defence slot, automatic) or
	  "boost" (no slot of its own: it boosts the next attack of its family
	  that is loaded, and is lost if there is none).
	- `territory`: "Grassland", "Hills", "River" or "Forest".
	- `size`: "Small", "Medium" or "Large" (rings are in `Config/Rings.luau`).
	- `showAt`: the attachment on the plant where the loaded power up shows
	  (Head, Jaw, Back, Tail, Hands or Feet).
	- `effect` (optional): replaces the family effect for this creature. For a
	  boost, it is what the boost adds to the attack.
	- `moveName` (special moves): shown on the slot button instead of a family.

	Durations that say "PerLevel" are multiplied by the user's level.
	Colours are { red, green, blue } from 0 to 255.
]]

local PowerUps = {}

PowerUps.families = table.freeze({
	Venom = table.freeze({
		name = "Venom",
		colour = table.freeze({ 150, 70, 200 }),
		-- Target can't use power ups for this long per attacker level.
		effect = table.freeze({ lockoutSecondsPerLevel = 0.5 }),
	}),
	-- The key stays "BiteAndSlash" so saved codex progress keeps working;
	-- players see "Slash" (Bite is the normal attack).
	BiteAndSlash = table.freeze({
		name = "Slash",
		colour = table.freeze({ 210, 50, 50 }),
		-- Multiplies the bite damage. Damage still stops at a level drop.
		effect = table.freeze({ damageMultiplier = 2 }),
	}),
	Strangle = table.freeze({
		name = "Strangle",
		colour = table.freeze({ 240, 140, 30 }),
		-- Target can't move for this long per attacker level.
		effect = table.freeze({ holdSecondsPerLevel = 0.5 }),
	}),
	SpecialMove = table.freeze({
		name = "Special move",
		colour = table.freeze({ 240, 210, 40 }),
		effect = table.freeze({}),
	}),
})

PowerUps.creatures = table.freeze({
	-- Venom
	spider = table.freeze({
		name = "Spider",
		showAt = "Jaw",
		family = "Venom",
		kind = "melee",
		territory = "Grassland",
		size = "Small",
	}),
	wasp = table.freeze({
		name = "Wasp",
		showAt = "Tail",
		family = "Venom",
		kind = "range",
		territory = "Forest",
		size = "Small",
	}),
	toad = table.freeze({
		name = "Toad",
		showAt = "Back",
		family = "Venom",
		kind = "defence",
		territory = "River",
		size = "Medium",
	}),
	-- Bee (boost): the next Venom attack's venom lasts twice as long and a
	-- venom sack sticks to the target.
	bee = table.freeze({
		name = "Bee",
		showAt = "Head",
		family = "Venom",
		kind = "boost",
		territory = "Hills",
		size = "Medium",
		effect = table.freeze({ lockoutMultiplier = 2, sticky = true }),
	}),

	-- Slash
	bullAnt = table.freeze({
		name = "Bull ant",
		showAt = "Jaw",
		family = "BiteAndSlash",
		kind = "melee",
		territory = "Hills",
		size = "Small",
	}),
	snake = table.freeze({
		name = "Snake",
		showAt = "Head",
		family = "BiteAndSlash",
		kind = "range",
		territory = "River",
		size = "Medium",
	}),
	snail = table.freeze({
		name = "Snail",
		showAt = "Back",
		family = "BiteAndSlash",
		kind = "defence",
		territory = "Forest",
		size = "Medium",
	}),
	-- Praying mantis (boost): the next Slash attack isn't used up,
	-- and can be used again after `reuseSeconds`.
	mantis = table.freeze({
		name = "Praying mantis",
		showAt = "Hands",
		family = "BiteAndSlash",
		kind = "boost",
		territory = "Grassland",
		size = "Medium",
		effect = table.freeze({ keepPowerUp = true, reuseSeconds = 0.8 }),
	}),

	-- Strangle
	eel = table.freeze({
		name = "Eel",
		showAt = "Back",
		family = "Strangle",
		kind = "melee",
		territory = "River",
		size = "Large",
	}),
	chameleon = table.freeze({
		name = "Chameleon",
		showAt = "Jaw",
		family = "Strangle",
		kind = "range",
		territory = "Hills",
		size = "Medium",
	}),
	skunk = table.freeze({
		name = "Skunk",
		showAt = "Back",
		family = "Strangle",
		kind = "defence",
		territory = "Grassland",
		size = "Large",
	}),
	-- Bombardier beetle (boost): the next Strangle attack also sprays acid,
	-- which removes the target's oldest power up.
	bombardierBeetle = table.freeze({
		name = "Bombardier beetle",
		showAt = "Head",
		family = "Strangle",
		kind = "boost",
		territory = "Forest",
		size = "Medium",
		effect = table.freeze({ removeOldestPowerUp = true }),
	}),

	-- Special moves
	bat = table.freeze({
		moveName = "Fly",
		name = "Bat",
		showAt = "Back",
		family = "SpecialMove",
		kind = "special",
		territory = "Hills",
		size = "Large",
		effect = table.freeze({ flySeconds = 6 }),
	}),
	-- Blowfish: ignore all attacks, puff into a ball and bounce away. The
	-- design gives no duration yet; 2 seconds is a placeholder.
	blowfish = table.freeze({
		moveName = "Puff",
		name = "Blowfish",
		showAt = "Head",
		family = "SpecialMove",
		kind = "special",
		territory = "River",
		size = "Large",
		effect = table.freeze({ ballSeconds = 2 }),
	}),
	centipede = table.freeze({
		moveName = "Dash",
		name = "Centipede",
		showAt = "Feet",
		family = "SpecialMove",
		kind = "special",
		territory = "Forest",
		size = "Small",
		effect = table.freeze({ speedBurst = 6, speedBurstSecondsPerLevel = 0.5 }),
	}),
	stickInsect = table.freeze({
		moveName = "Hide",
		name = "Stick insect",
		showAt = "Back",
		family = "SpecialMove",
		kind = "special",
		territory = "Grassland",
		size = "Small",
		effect = table.freeze({ invisibleSecondsPerLevel = 1 }),
	}),
})

return table.freeze(PowerUps)
