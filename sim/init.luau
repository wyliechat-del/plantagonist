--[[
	Ring economy simulator. Run from the repo root with: lune run sim

	Plays thousands of sessions per player profile (see sim/Assumptions.luau)
	with the real Rules and Config and prints how long it takes to reach each
	level, compared with the targets in sim/Assumptions.luau.
]]

local Levels = require("./src/shared/Config/Levels")
local Assumptions = require("@self/Assumptions")
local Simulator = require("@self/Simulator")

local function clock(seconds: number?): string
	if seconds == nil then
		return "  -  "
	end
	return string.format("%2d:%02d", seconds // 60, math.floor(seconds % 60))
end

local function pad(text: string, width: number): string
	return text .. string.rep(" ", math.max(0, width - #text))
end

for _, profile in Assumptions.profiles do
	local result = Simulator.run(
		profile,
		Assumptions.sessionsPerProfile,
		Assumptions.sessionSeconds,
		Assumptions.seed
	)
	print(
		`\n{profile.name} ({Assumptions.sessionsPerProfile} sessions of {clock(
			Assumptions.sessionSeconds
		)})`
	)
	print(`  {pad("Level", 22)} reached   fast  median   slow`)
	for level = 2, Simulator.rootLevel do
		local stats = result.levels[level]
		local name = if level <= #Levels.list
			then `{level} {Levels.list[level].name}`
			else `{level} Root (Deciduodocus)`
		print(
			`  {pad(name, 22)} {string.format("%5.0f%%", stats.share * 100)}   {clock(stats.p10)}  {clock(
				stats.median
			)}  {clock(stats.p90)}`
		)
	end
	local from = result.ringsFrom
	print(
		string.format(
			"  Rings per session: flies %.0f, creatures %.0f, plants %.0f, rain %.0f, lost %.0f",
			from.flies,
			from.creatures,
			from.plants,
			from.rain,
			from.lost
		)
	)
	if profile.name == Assumptions.targetProfile then
		for _, target in Assumptions.targets do
			local median = result.levels[target.level].median
			local verdict = if median == nil
				then "missed (under half the sessions got there)"
				elseif
					median < target.seconds * (1 - Assumptions.tolerance)
				then "faster than target"
				elseif
					median > target.seconds * (1 + Assumptions.tolerance)
				then "slower than target"
				else "on target"
			print(
				`  Target {target.label} by {clock(target.seconds)}: median {clock(median)}, {verdict}`
			)
		end
	end
end
print("\n'fast' is the 10th percentile, 'slow' the 90th. '-' means too few sessions got there.")
