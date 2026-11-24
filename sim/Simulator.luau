--[[
	Ring economy simulator. Plays out one player's session at a time with the
	real Rules and Config, plus the behaviour guesses in Assumptions, and
	records when the player first reaches each level.

	It is a rough model: one player, the world reduced to "how long until the
	next creature, fight, rain cloud or bigger plant". It is for comparing
	numbers before playtests, not for predicting exact times.
]]

local Combat = require("../src/shared/Config/Combat")
local Environment = require("../src/shared/Config/Environment")
local Levels = require("../src/shared/Config/Levels")
local Rings = require("../src/shared/Config/Rings")
local Bite = require("../src/shared/Rules/Bite")
local Growth = require("../src/shared/Rules/Growth")
local Random = require("./Random")

local Simulator = {}

export type SessionResult = {
	reachedAt: { [number]: number }, -- level (7 = rooted) to first second reached
	ringsFrom: { [string]: number }, -- rings gained by source
}

local ROOT_LEVEL = #Levels.list + 1

local function pickSize(rng: Random.Random, weights: { [string]: number }): string
	local roll = rng:float()
	for _, size in { "Small", "Medium", "Large" } do
		roll -= weights[size] or 0
		if roll < 0 then
			return size
		end
	end
	return "Small"
end

-- Plays one fight against a smaller plant. Returns (seconds, rings gained).
local function fight(rng: Random.Random, profile: any, level: number): (number, number)
	local victimLevel = math.max(1, level - 1)
	local low = Levels.list[victimLevel].minRings
	local high = (
		Levels.list[victimLevel + 1] and Levels.list[victimLevel + 1].minRings or Levels.rootRings
	) - 1
	local victimRings = rng:int(low, high)
	local seconds, gained = profile.chaseSeconds, 0
	while true do
		local floor = Growth.dropFloor(Levels.list, Growth.levelFor(Levels.list, victimRings))
		local result = Bite.resolve(Combat, level, victimRings, floor)
		seconds += Combat.biteCooldown
		gained += result.toBiter + math.floor(result.toNuts * profile.nutPickupShare)
		victimRings = result.victimRings
		if result.eaten then
			gained += Bite.eatBonus(Combat, victimLevel)
			break
		end
		if result.droppedLevel then
			if rng:chance(profile.victimEscapeChance) then
				break
			end
			seconds += Combat.escapeSeconds
		end
	end
	return seconds, gained
end

function Simulator.session(profile: any, sessionSeconds: number, rng: Random.Random): SessionResult
	local now, rings, fertilised = 0, Levels.respawnRings, false
	local nextRain =
		rng:int(Environment.Rain.minIntervalSeconds, Environment.Rain.maxIntervalSeconds)
	local reachedAt = { [1] = 0 }
	local ringsFrom = { flies = 0, creatures = 0, plants = 0, rain = 0, lost = 0 }

	local function gain(source: string, amount: number)
		local before = rings
		rings = Growth.addRings(rings, amount, Levels.rootRings)
		ringsFrom[source] += rings - before
		local level = Growth.levelFor(Levels.list, rings)
		for reached = 1, level do
			reachedAt[reached] = reachedAt[reached] or now
		end
	end

	while now < sessionSeconds do
		local level = Growth.levelFor(Levels.list, rings)
		local seconds = 0

		if rings < Rings.fliesMaxRings then
			-- Conservatory: eat flies until they stop paying.
			seconds = profile.flySeconds
			now += seconds
			gain("flies", Growth.flyRings(Rings, rings))
		elseif rng:chance(profile.fightChance) then
			local fightSeconds, gained = fight(rng, profile, level)
			seconds = fightSeconds
			now += seconds
			gain("plants", gained)
		else
			seconds = profile.searchStuds
					/ Growth.studsPerSecond(Levels.list, Levels.studsPerSpeedUnit, level)
				+ profile.eatSeconds
			if rng:chance(profile.pooChance) then
				seconds += profile.pooSeconds
				fertilised = true
			end
			now += seconds
			local size = pickSize(rng, profile.sizeWeights)
			gain(
				"creatures",
				Growth.creatureRings(Rings, size, fertilised, function(min, max)
					return rng:int(min, max)
				end)
			)
			fertilised = false
		end

		if now >= nextRain then
			if rng:chance(profile.rainCatchChance) then
				gain("rain", Growth.rainRings(Rings, Growth.levelFor(Levels.list, rings)))
			end
			nextRain = now
				+ rng:int(Environment.Rain.minIntervalSeconds, Environment.Rain.maxIntervalSeconds)
		end

		-- A bigger plant knocks this one down a level now and then.
		level = Growth.levelFor(Levels.list, rings)
		if level > 1 and rng:chance(profile.levelDropsPerMinute * seconds / 60) then
			local before = rings
			rings = Growth.dropFloor(Levels.list, level)
			ringsFrom.lost += before - rings
		end

		if Growth.canRoot(rings, Levels.rootRings) then
			reachedAt[ROOT_LEVEL] = now
			break
		end
	end

	return { reachedAt = reachedAt, ringsFrom = ringsFrom }
end

export type LevelStats = {
	share: number, -- share of sessions that reached the level
	p10: number?,
	median: number?,
	p90: number?,
}

-- Runs many sessions for one profile and summarises the times.
function Simulator.run(profile: any, sessions: number, sessionSeconds: number, seed: number)
	local rng = Random.new(seed)
	local times: { [number]: { number } } = {}
	for level = 1, ROOT_LEVEL do
		times[level] = {}
	end
	local ringsFrom = { flies = 0, creatures = 0, plants = 0, rain = 0, lost = 0 }
	for _ = 1, sessions do
		local result = Simulator.session(profile, sessionSeconds, rng)
		for level, at in result.reachedAt do
			table.insert(times[level], at)
		end
		for source, amount in result.ringsFrom do
			ringsFrom[source] += amount / sessions
		end
	end
	local stats: { [number]: LevelStats } = {}
	for level = 1, ROOT_LEVEL do
		local list = times[level]
		table.sort(list)
		-- Times for sessions that never reached the level count as "after the end",
		-- so the median is only shown when at least half the sessions got there.
		local function at(share: number): number?
			if #list < math.ceil(sessions * share) then
				return nil
			end
			return list[math.max(1, math.ceil(sessions * share))]
		end
		stats[level] = {
			share = #list / sessions,
			p10 = at(0.1),
			median = at(0.5),
			p90 = at(0.9),
		}
	end
	return { levels = stats, ringsFrom = ringsFrom }
end

Simulator.rootLevel = ROOT_LEVEL

return Simulator
