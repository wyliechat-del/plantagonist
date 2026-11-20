--[[
	Config: every number a designer might tweak lives under this folder
	(speeds, costs, timers, growth rates). Game code reads values from here
	and never hard-codes them, so balancing the game is a data change.

	Rules for this folder:
	- Plain Luau tables only. No Roblox objects, services or `game`.
	- Split by topic as it grows, one child module per topic, for example
	  `Config/Plants.luau`. Modules here require nothing.
	- The returned table is frozen so nothing changes config at runtime.
]]

local Config = {}

return table.freeze(Config)
