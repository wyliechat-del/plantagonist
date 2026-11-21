--[[
	Guesses about how players behave, used only by the simulator. These are
	not game numbers (those are in src/shared/Config). Replace the guesses
	with real numbers from playtest logs when we have them.

	Each profile is one kind of player.
]]

local Assumptions = {}

Assumptions.sessionSeconds = 600
Assumptions.sessionsPerProfile = 2000
Assumptions.seed = 20261121

-- Where a good player should be, from the design doc.
Assumptions.targets = {
	{ label = "Level 4", level = 4, seconds = 180 },
	{ label = "Level 6", level = 6, seconds = 420 },
	{ label = "Root", level = 7, seconds = 540 },
}

Assumptions.profiles = {
	{
		name = "Good player",
		-- Seconds to catch one fly in the conservatory (other players compete).
		flySeconds = 4,
		-- Studs walked to find the next creature, and seconds to eat it.
		searchStuds = 50,
		eatSeconds = 1,
		-- Share of creatures by size (adds up to 1).
		sizeWeights = { Small = 0.5, Medium = 0.35, Large = 0.15 },
		-- Chance a hunt also finds cow poo, and the extra seconds it costs.
		pooChance = 0.1,
		pooSeconds = 3,
		-- Chance the next thing the player does is attack a smaller plant.
		fightChance = 0.15,
		chaseSeconds = 6,
		-- Each time the victim drops a level, the chance it gets away.
		victimEscapeChance = 0.3,
		-- Share of spilled nuts the attacker picks up.
		nutPickupShare = 0.5,
		-- How often a bigger plant knocks this player down one level.
		levelDropsPerMinute = 0.3,
		-- Chance the player gets to a rain cloud in time.
		rainCatchChance = 0.5,
	},
	{
		name = "Casual player",
		flySeconds = 5,
		searchStuds = 80,
		eatSeconds = 1.5,
		sizeWeights = { Small = 0.55, Medium = 0.33, Large = 0.12 },
		pooChance = 0.05,
		pooSeconds = 4,
		fightChance = 0.05,
		chaseSeconds = 8,
		victimEscapeChance = 0.5,
		nutPickupShare = 0.3,
		levelDropsPerMinute = 0.6,
		rainCatchChance = 0.25,
	},
}

return Assumptions
