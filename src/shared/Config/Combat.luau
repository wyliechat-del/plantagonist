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
-- at `projectileStudsPerSecond`, so they can be dodged. Since playtest 3 every
-- level has the same range.
Combat.rangeBaseStuds = 50
Combat.rangeStudsPerLevel = 0
Combat.projectileStudsPerSecond = 20

-- Bite and melee reach from the plant's edge, the same for creatures and
-- plants and for every level since playtest 3 (big plants still reach a bit
-- further from their centre because they are wider).
Combat.biteReachBaseStuds = 9
Combat.biteReachStudsPerLevel = 0

-- Big plants (from `roarFromLevel`) roar for `roarSeconds` before a bite or
-- melee hit on a plant lands, so small plants can dart in and out. Bites on
-- creatures don't roar. A target that gets out of reach during the roar is
-- missed.
Combat.roarFromLevel = 4
Combat.roarSeconds = 0.25

-- Big plants (from `liftFromLevel`) that bite or melee hit a smaller plant
-- hold it in their mouth for `liftSeconds`, then toss it (like a cow).
-- `liftHeight` is studs above the biter's root per unit of the biter's scale.
Combat.liftFromLevel = 4
Combat.liftSeconds = 0.5
Combat.liftHeight = 3.5

-- Big plants (from `staggerFromLevel`) that get hit stagger: they can't move
-- for `staggerSeconds` and are nudged back at `staggerStepSpeed` studs per
-- second (about one step).
Combat.staggerFromLevel = 4
Combat.staggerSeconds = 0.25
Combat.staggerStepSpeed = 12

-- When a defence blocks a power up attack, does the attack's normal bite
-- damage still land? The design says defences don't block the basic bite.
Combat.defenceBlocksBiteDamage = false

return table.freeze(Combat)
