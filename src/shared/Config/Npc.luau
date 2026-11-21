--[[
	NPC plants that wander, eat and fight so small playtests feel busy.
]]

local Npc = {}

-- The server adds NPC plants until players plus NPCs reach this number.
Npc.targetPlants = 8
-- NPCs never go above this level, so they stay beatable. They don't root.
Npc.maxLevel = 5

-- Seconds between decisions.
Npc.thinkEverySeconds = 0.5

-- What an NPC notices, in studs.
Npc.sightDistance = 60
-- An NPC flees plants at least this many levels bigger than itself.
Npc.fleeLevelGap = 2
-- An NPC hunts plants at least this many levels smaller than itself.
Npc.huntLevelGap = 1
-- Chance per decision that an NPC uses a loaded power up on its target.
Npc.powerUpChance = 0.3

Npc.names = table.freeze({
	"Sprouty",
	"Chompers",
	"Mossy",
	"Fernando",
	"Snapdragon",
	"Leafy",
	"Thistle",
	"Basil",
})

return table.freeze(Npc)
