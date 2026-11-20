--[[
	Rules: the game's logic written as plain functions over plain data
	(for example "how much does this upgrade cost at level n").

	Rules for this folder:
	- No Roblox objects, services or `game`, so every rule can be unit tested
	  on a normal computer with `lune run tests`.
	- Read numbers from Config instead of writing them inline.
	- One module per topic, added below with `require("@self/<Topic>")`.
]]

local Rules = {}

return table.freeze(Rules)
