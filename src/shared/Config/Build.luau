--[[
	The build shown on the flag in the middle of the spawn area, so playtesters
	can tell which build they are on. Bump `number` with every playtest build.
]]

local Build = {}

Build.number = "15C"
Build.date = "2026-11-27"

-- Flag size in studs, and how far from the spawn pad it stands (plain
-- numbers so this file loads in Lune too).
Build.poleHeight = 14
Build.flagWidth = 8
Build.flagHeight = 4.5
Build.offsetFromSpawn = 9

return table.freeze(Build)
