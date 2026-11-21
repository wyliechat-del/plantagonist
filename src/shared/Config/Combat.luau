--[[
	Bites between plants, ranged attacks and the safety timers around fights.
]]

local Combat = {}

-- A bite takes this many rings per attacker level.
Combat.ringsPerAttackerLevel = 1

-- Seconds between bites by the same plant.
Combat.biteCooldown = 0.8

-- Share of each bite's rings that goes to the biter. The rest spills on the
-- ground as nuts. The biter's share is rounded up, so a 1 ring peck still pays.
Combat.biterShare = 0.5

-- Rings each nut is worth when eaten.
Combat.ringsPerNut = 1

-- Eating a plant (bringing it to 0 rings) pays this many rings per victim level.
Combat.eatBonusPerVictimLevel = 2

-- After dropping a level, a plant can't be bitten for this long.
Combat.escapeSeconds = 1.5

-- After leaving the conservatory, a plant can't be bitten for this long.
Combat.spawnProtectionSeconds = 3

-- Ranged power ups reach `rangeBaseStuds + rangeStudsPerLevel * level` and fly
-- at `projectileStudsPerSecond`, so they can be dodged.
Combat.rangeBaseStuds = 15
Combat.rangeStudsPerLevel = 5
Combat.projectileStudsPerSecond = 20

-- Melee reach. Placeholder numbers, not in the design yet; big plants get a
-- longer reach so they stay a threat while slow. Tune in playtests.
Combat.biteReachBaseStuds = 4
Combat.biteReachStudsPerLevel = 1

-- When a defence blocks a power up attack, does the attack's normal bite
-- damage still land? The design says defences don't block the basic bite.
Combat.defenceBlocksBiteDamage = false

return table.freeze(Combat)
