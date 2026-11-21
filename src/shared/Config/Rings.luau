--[[
	Where rings come from (other than biting plants, which is in Combat).
]]

local Rings = {}

-- Rings for eating a creature, by its size.
Rings.bySize = table.freeze({ Small = 1, Medium = 2, Large = 3 })

-- Flies give rings only while the eater is at or below `fliesMaxLevel`.
Rings.perFly = 1
Rings.fliesMaxLevel = 2

-- Cow poo sets the Fertiliser flag: the next creature eaten gives a random
-- number of rings in this range instead of its size value.
Rings.fertilisedMin = 2
Rings.fertilisedMax = 6

-- Touching rain gives this many rings per level.
Rings.rainPerLevel = 1

-- Wilting: plants at or above `wiltFromLevel` lose `wiltRings` every
-- `wiltEverySeconds`, so taking root becomes the smart move.
Rings.wiltFromLevel = 6
Rings.wiltRings = 1
Rings.wiltEverySeconds = 10

return table.freeze(Rings)
