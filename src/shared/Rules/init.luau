--[[
	Rules: the game's logic written as plain functions over plain data
	(for example "how much does this upgrade cost at level n").

	Rules for this folder:
	- No Roblox objects, services or `game`, so every rule can be unit tested
	  on a normal computer with `lune run tests`.
	- Modules here require nothing. A rule takes the Config values it needs as
	  arguments, so tests can pass in any numbers they like.
	- One child module per topic, for example `Rules/Growth.luau`.
]]

local Rules = {}

return table.freeze(Rules)
