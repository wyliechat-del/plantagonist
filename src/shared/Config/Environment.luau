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
	-- Trees can't root inside the safe field or closer than this to another tree.
	minTreeSpacing = 30,
	-- Placeholder tree size in studs.
	trunkHeight = 40,
	crownSize = 36,
})

return table.freeze(Environment)
