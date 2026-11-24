--[[
	World events: rain clouds and rooted trees.
]]

local Environment = {}

Environment.Rain = table.freeze({
	-- A new rain cloud appears after a random wait in this range.
	minIntervalSeconds = 60,
	maxIntervalSeconds = 120,
	-- How long it rains once the shadow has shrunk to a cloud.
	rainSeconds = 5,
	-- The shadow starts this wide (radius, studs) and shrinks to the cloud's
	-- radius over `shadowSeconds`, warning players where the rain will fall.
	shadowSeconds = 10,
	shadowStartRadius = 60,
	cloudRadius = 14,
	cloudHeight = 45,
	shadowTransparency = 0.15,
	-- Glowing rings sweep in across the territory to the spot where rain
	-- will fall: `ringCount` rings, each made of `ringSegments` pieces,
	-- shrinking from `ringStartRadius` over `ringSeconds`, one after another.
	ringCount = 3,
	ringSegments = 36,
	ringStartRadius = 150,
	ringSeconds = 3,
	-- Lightning flashes from the cloud in the last seconds before the rain.
	lightningFlashes = 3,
	lightningSeconds = 3,
})

Environment.Rooting = table.freeze({
	name = "Deciduodocus",
	-- How long a rooted tree stands.
	treeSeconds = 120,
	-- Every `fruitEverySeconds` the tree drops between min and max fruit.
	fruitEverySeconds = 20,
	fruitMin = 2,
	fruitMax = 6,
	-- The rooted player respawns with one fruit (a random power up) to eat.
	respawnFruit = 1,
	-- After rooting the player watches the tree grow for `growSeconds` (from
	-- `growStartScale` of its size) and drop its first fruit. Then a Respawn
	-- button shows; the player respawns anyway after `watchSeconds`.
	growSeconds = 3,
	growStartScale = 0.05,
	growSteps = 30,
	watchSeconds = 20,
	-- The camera circles the tree at this distance and height while watching.
	cameraDistance = 80,
	cameraHeight = 40,
	cameraDegreesPerSecond = 12,
	-- Trees can't root inside the safe field or closer than this to another tree.
	minTreeSpacing = 30,
	-- Placeholder tree size in studs.
	trunkHeight = 40,
	crownSize = 36,
})

return table.freeze(Environment)
