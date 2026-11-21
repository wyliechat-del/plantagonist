--[[
	Creature spawning and movement. Which creatures exist and what they give
	is in `Config/PowerUps.luau` and `Config/Rings.luau`.
]]

local Creatures = {}

-- How many creatures each territory keeps alive at once.
Creatures.capPerTerritory = 18

-- Seconds between spawn checks.
Creatures.spawnEverySeconds = 2

-- Movement in studs per second. Catching creatures shouldn't be the
-- challenge, so they are much slower than every plant (a Rex runs at 6).
Creatures.wanderSpeed = 2
-- A creature only dodges at the last moment: when a plant comes within
-- `dodgeDistance` studs it runs at `dodgeSpeed` for `dodgeSeconds`,
-- then can't dodge again for `dodgeCooldown` seconds.
Creatures.dodgeDistance = 6
Creatures.dodgeSpeed = 4
Creatures.dodgeSeconds = 1.5
Creatures.dodgeCooldown = 2
-- Creatures won't walk up anything steeper than this many studs per step,
-- so they go round hills instead of through them.
Creatures.maxClimb = 1.5
-- Where creatures spawn: share in their own territory, in the two
-- neighbouring territories, and in the opposite one.
Creatures.spawnMix = table.freeze({ native = 0.7, neighbour = 0.2, opposite = 0.1 })
-- A wandering creature picks a new spot within this distance.
Creatures.wanderRadius = 30

-- Body size in studs by creature size.
Creatures.bodySize = table.freeze({ Small = 1.5, Medium = 2.5, Large = 3.5 })

-- Flies in the conservatory and field.
Creatures.flies = table.freeze({
	cap = 25,
	speed = 3,
	size = 0.8,
	hoverHeight = 3,
})

-- Cows in the Grassland drop cow poo as they wander.
Creatures.cows = table.freeze({
	count = 4,
	speed = 3,
	pooEverySeconds = 25,
	pooCap = 12,
	-- Plants of this level or bigger can pick up a cow with a bite, chew on
	-- it for `holdSeconds` and toss it. No rings, just fun.
	pickUpLevel = 5,
	holdSeconds = 1,
	-- How high above the plant's root the cow is held, per unit of plant scale.
	holdHeight = 4,
	-- Toss speed in studs per second (forward and up), and the fall speed gain.
	tossSpeed = 35,
	tossUpSpeed = 30,
	tossGravity = 120,
	-- Half the cow's height, so it stands on the ground.
	standHeight = 1.75,
})

return table.freeze(Creatures)
