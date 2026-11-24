--[[
	Plant levels 1 to 6, reached by collecting tree rings. Level 7 (the rooted
	Deciduodocus) is a choice, not a ring range; its numbers are in
	`Config/Environment.luau` under `Rooting`.

	`minRings` is the first ring count of each level. A level runs up to one
	ring below the next level's `minRings`. Speed is in speed units; one unit is
	`studsPerSpeedUnit` studs per second.
]]

local Levels = {}

Levels.list = table.freeze({
	table.freeze({
		name = "Seedling",
		minRings = 1,
		attackSlots = 1,
		defenceSlots = 0,
		speed = 4.2,
	}),
	table.freeze({
		name = "Budteryx",
		minRings = 4,
		attackSlots = 2,
		defenceSlots = 0,
		speed = 4.2,
	}),
	table.freeze({
		name = "Saplodocus",
		minRings = 10,
		attackSlots = 2,
		defenceSlots = 1,
		speed = 4.2,
	}),
	table.freeze({
		name = "Shrubosaurus",
		minRings = 20,
		attackSlots = 3,
		defenceSlots = 1,
		speed = 3,
	}),
	table.freeze({
		name = "Bushiraptor",
		minRings = 36,
		attackSlots = 3,
		defenceSlots = 2,
		speed = 3,
	}),
	table.freeze({
		name = "Snaposaurus Rex",
		minRings = 57,
		attackSlots = 3,
		defenceSlots = 2,
		speed = 3,
	}),
})

-- At this many rings a plant may choose to take root. Rings never go higher.
Levels.rootRings = 80

-- 1 speed unit = 4 studs per second. Two speeds (playtest 3): levels 1 to 3
-- run at about 17 studs per second and levels 4 to 6 at 12, so growing
-- doesn't feel like a downgrade.
Levels.studsPerSpeedUnit = 4

-- Rings a plant has when it respawns as a Seedling.
Levels.respawnRings = 1

return table.freeze(Levels)
