--[[
	NPC plant decisions. Takes `Config/Npc.luau` as `npc`.

	`self` is { level, x, z, hasAttack }. `plants` and `creatures` are lists of
	{ key, level?, x, z } that the NPC can see (already filtered by sight).
	Returns an action: { kind = "flee", key }, { kind = "hunt", key },
	{ kind = "eat", key } or { kind = "wander" }.
]]

local NpcRules = {}

export type Seen = { key: any, level: number?, x: number, z: number }
export type Action = { kind: string, key: any? }

local function nearest(
	selfX: number,
	selfZ: number,
	list: { Seen },
	filter: (Seen) -> boolean
): Seen?
	local best, bestDistance = nil, math.huge
	for _, item in list do
		if filter(item) then
			local dx, dz = item.x - selfX, item.z - selfZ
			local distance = dx * dx + dz * dz
			if distance < bestDistance then
				best, bestDistance = item, distance
			end
		end
	end
	return best
end

function NpcRules.decide(
	npc: any,
	self: { level: number, x: number, z: number },
	plants: { Seen },
	creatures: { Seen }
): Action
	local threat = nearest(self.x, self.z, plants, function(plant)
		return (plant.level or 1) >= self.level + npc.fleeLevelGap
	end)
	if threat then
		return { kind = "flee", key = threat.key }
	end
	local prey = nearest(self.x, self.z, plants, function(plant)
		return (plant.level or 1) <= self.level - npc.huntLevelGap
	end)
	if prey then
		return { kind = "hunt", key = prey.key }
	end
	local food = nearest(self.x, self.z, creatures, function()
		return true
	end)
	if food then
		return { kind = "eat", key = food.key }
	end
	return { kind = "wander" }
end

return table.freeze(NpcRules)
