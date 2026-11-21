--[[
	Where rings come from (other than biting plants, which is in Combat).
	Nothing in the world takes rings away; only other plants' bites do.
]]

local Rings = {}

-- Rings for eating a creature, by its size.
Rings.bySize = table.freeze({ Small = 1, Medium = 2, Large = 3 })

-- Flies give rings only while the eater has fewer than `fliesMaxRings`
-- rings, so they feed Seedlings and never take anyone past 4 rings.
Rings.perFly = 1
Rings.fliesMaxRings = 4

-- Cow poo sets the Fertiliser flag: the next creature eaten gives a random
-- number of rings in this range instead of its size value.
Rings.fertilisedMin = 2
Rings.fertilisedMax = 6

-- Touching rain gives this many rings per level.
Rings.rainPerLevel = 1

return table.freeze(Rings)
