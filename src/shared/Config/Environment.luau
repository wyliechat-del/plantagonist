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
})

Environment.Rooting = table.freeze({
	name = "Deciduodocus",
	-- How long a rooted tree stands.
	treeSeconds = 120,
	-- Every `fruitEverySeconds` the tree drops between min and max fruit.
	fruitEverySeconds = 20,
	fruitMin = 2,
	fruitMax = 6,
})

return table.freeze(Environment)
