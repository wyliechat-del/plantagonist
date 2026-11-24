--[[
	A small seeded random number generator (Park-Miller), so simulator runs
	give the same answer every time for the same seed.
]]

local Random = {}
Random.__index = Random

export type Random = typeof(setmetatable({} :: { state: number }, Random))

local MODULUS = 2147483647
local MULTIPLIER = 48271

function Random.new(seed: number): Random
	local state = seed % MODULUS
	if state <= 0 then
		state += MODULUS - 1
	end
	return setmetatable({ state = state }, Random)
end

-- A number in [0, 1).
function Random.float(self: Random): number
	self.state = (self.state * MULTIPLIER) % MODULUS
	return (self.state - 1) / (MODULUS - 1)
end

-- A whole number in [min, max].
function Random.int(self: Random, min: number, max: number): number
	return min + math.floor(self:float() * (max - min + 1))
end

function Random.chance(self: Random, probability: number): boolean
	return self:float() < probability
end

return Random
