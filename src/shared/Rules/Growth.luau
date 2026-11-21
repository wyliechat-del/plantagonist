--[[
	Levels and rings: which level a ring count is, how fast that level runs,
	and the ring rewards that don't involve biting plants.

	Takes Config tables as arguments (`Config/Levels.luau`, `Config/Rings.luau`).
]]

local Growth = {}

export type LevelInfo = {
	name: string,
	minRings: number,
	attackSlots: number,
	defenceSlots: number,
	speed: number,
}

-- The level for a ring count. 0 rings still counts as level 1 (the plant is
-- being eaten); use `isEaten` to tell the difference.
function Growth.levelFor(levels: { LevelInfo }, rings: number): number
	local level = 1
	for index, info in levels do
		if rings >= info.minRings then
			level = index
		end
	end
	return level
end

-- The ring count a plant falls to when it drops out of `level`: one below the
-- level's first ring. For level 1 that is 0, which means eaten.
function Growth.dropFloor(levels: { LevelInfo }, level: number): number
	return levels[level].minRings - 1
end

function Growth.isEaten(rings: number): boolean
	return rings <= 0
end

-- Running speed in studs per second.
function Growth.studsPerSecond(
	levels: { LevelInfo },
	studsPerSpeedUnit: number,
	level: number
): number
	return levels[level].speed * studsPerSpeedUnit
end

-- Adds (or with a negative amount, removes) rings, kept between 0 and `maxRings`.
function Growth.addRings(rings: number, amount: number, maxRings: number): number
	return math.clamp(rings + amount, 0, maxRings)
end

function Growth.canRoot(rings: number, rootRings: number): boolean
	return rings >= rootRings
end

-- Rings for eating a creature of `size`. When `fertilised`, `roll(min, max)`
-- picks the reward instead. `roll` returns a whole number in [min, max].
function Growth.creatureRings(
	ringConfig: any,
	size: string,
	fertilised: boolean,
	roll: (number, number) -> number
): number
	if fertilised then
		return roll(ringConfig.fertilisedMin, ringConfig.fertilisedMax)
	end
	local rings = ringConfig.bySize[size]
	assert(rings, `unknown creature size "{size}"`)
	return rings
end

function Growth.flyRings(ringConfig: any, rings: number): number
	if rings < ringConfig.fliesMaxRings then
		return ringConfig.perFly
	end
	return 0
end

function Growth.rainRings(ringConfig: any, level: number): number
	return ringConfig.rainPerLevel * level
end

return table.freeze(Growth)
