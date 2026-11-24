--[[
	Award progress. Takes `Config/Awards.luau` (`awards`) and
	`Config/PowerUps.luau` (`powerUps`).

	Progress is a plain table that is saved as is:
	{ counters = { [stat] = n }, eaten = { [creatureId] = n },
	  used = { [creatureId] = n }, earned = { [awardId] = true } }

	These functions change the progress table they are given.
]]

local AwardRules = {}

export type Progress = {
	counters: { [string]: number },
	eaten: { [string]: number },
	used: { [string]: number },
	earned: { [string]: boolean },
}

function AwardRules.newProgress(): Progress
	return { counters = {}, eaten = {}, used = {}, earned = {} }
end

-- Fills in any missing parts of saved progress (for older saves).
function AwardRules.repair(progress: any): Progress
	if type(progress) ~= "table" then
		return AwardRules.newProgress()
	end
	for _, key in { "counters", "eaten", "used", "earned" } do
		if type(progress[key]) ~= "table" then
			progress[key] = {}
		end
	end
	return progress
end

function AwardRules.addCount(progress: Progress, stat: string, amount: number?)
	progress.counters[stat] = (progress.counters[stat] or 0) + (amount or 1)
end

function AwardRules.recordEaten(progress: Progress, creatureId: string)
	progress.eaten[creatureId] = (progress.eaten[creatureId] or 0) + 1
	AwardRules.addCount(progress, "creaturesEaten")
end

function AwardRules.recordUsed(progress: Progress, creatureId: string)
	progress.used[creatureId] = (progress.used[creatureId] or 0) + 1
end

local function allInFamily(powerUps: any, family: string?, counts: { [string]: number }): boolean
	for id, creature in powerUps.creatures do
		if (family == nil or creature.family == family) and (counts[id] or 0) < 1 then
			return false
		end
	end
	return true
end

function AwardRules.isMet(powerUps: any, award: any, progress: Progress): boolean
	if award.kind == "count" then
		return (progress.counters[award.stat] or 0) >= award.target
	elseif award.kind == "eatCreature" then
		return (progress.eaten[award.creature] or 0) >= award.target
	elseif award.kind == "eatFamily" then
		return allInFamily(powerUps, award.family, progress.eaten)
	elseif award.kind == "useFamily" then
		return allInFamily(powerUps, award.family, progress.used)
	elseif award.kind == "eatAll" then
		return allInFamily(powerUps, nil, progress.eaten)
	end
	error(`unknown award kind "{award.kind}"`)
end

-- Marks and returns awards that are met but weren't earned before.
function AwardRules.collectNew(awards: any, powerUps: any, progress: Progress): { any }
	local new = {}
	for _, award in awards.list do
		if not progress.earned[award.id] and AwardRules.isMet(powerUps, award, progress) then
			progress.earned[award.id] = true
			table.insert(new, award)
		end
	end
	return new
end

return table.freeze(AwardRules)
