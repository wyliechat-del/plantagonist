--[[
	Creature spawning and movement. Which creatures exist and what they give
	is in `Config/PowerUps.luau` and `Config/Rings.luau`.
]]

local Creatures = {}

-- How many creatures each territory keeps alive at once.
Creatures.capPerTerritory = 18

-- Seconds between spawn checks.
Creatures.spawnEverySeconds = 2

-- Movement in studs per second. Creatures are a little slower than a
-- Seedling (14) so new players can catch them.
Creatures.wanderSpeed = 5
Creatures.fleeSpeed = 11
-- A creature flees from plants closer than this.
Creatures.fleeDistance = 18
-- A wandering creature picks a new spot within this distance.
Creatures.wanderRadius = 30

-- Body size in studs by creature size.
Creatures.bodySize = table.freeze({ Small = 1.5, Medium = 2.5, Large = 3.5 })

-- Flies in the conservatory and field.
Creatures.flies = table.freeze({
	cap = 25,
	speed = 6,
	size = 0.8,
	hoverHeight = 3,
})

-- Cows in the Grassland drop cow poo as they wander.
Creatures.cows = table.freeze({
	count = 4,
	speed = 3,
	pooEverySeconds = 25,
	pooCap = 12,
})

return table.freeze(Creatures)
