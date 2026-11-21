--[[
	What each power up does when used. Takes `Config/PowerUps.luau` as
	`powerUps`.

	Attack power ups ("melee" and "range") hit a target, do normal bite damage
	(times any `damageMultiplier`) and apply their effect. "special" power ups
	act on the user. "defence" power ups sit in defence slots and block one
	power up attack of their own family, then are used up. Defences never
	block the basic bite. "boost" power ups ride on an attack of their family
	and change what it does once.
]]

local PowerUps = {}

export type AttackEffect = {
	damageMultiplier: number,
	lockoutSeconds: number, -- target can't use power ups
	holdSeconds: number, -- target can't move
	removeOldestPowerUp: boolean,
	sticky: boolean, -- show a venom sack stuck to the target
}

export type SelfEffect = {
	flySeconds: number,
	ballSeconds: number, -- ignore all attacks and bounce away
	speedBurst: number?, -- speed units while the burst lasts
	speedBurstSeconds: number,
	invisibleSeconds: number,
}

local function creature(powerUps: any, id: string): any
	local info = powerUps.creatures[id]
	assert(info, `unknown power up "{id}"`)
	return info
end

-- The creature's own effect if it has one, else its family's effect.
function PowerUps.effectOf(powerUps: any, id: string): any
	local info = creature(powerUps, id)
	return info.effect or powerUps.families[info.family].effect
end

function PowerUps.familyOf(powerUps: any, id: string): string
	return creature(powerUps, id).family
end

function PowerUps.kindOf(powerUps: any, id: string): string
	return creature(powerUps, id).kind
end

function PowerUps.isBoost(powerUps: any, id: string): boolean
	return creature(powerUps, id).kind == "boost"
end

-- Which slots a power up goes in: "attack", "defence" or "boost" (rides on
-- an attack slot, see `canBoost`).
function PowerUps.slotTypeFor(powerUps: any, id: string): "attack" | "defence" | "boost"
	local kind = creature(powerUps, id).kind
	if kind == "defence" then
		return "defence"
	elseif kind == "boost" then
		return "boost"
	end
	return "attack"
end

function PowerUps.isAttack(powerUps: any, id: string): boolean
	local kind = creature(powerUps, id).kind
	return kind == "melee" or kind == "range"
end

-- Can boost `boostId` ride on the attack power up `attackId`?
function PowerUps.canBoost(powerUps: any, boostId: string, attackId: string): boolean
	return PowerUps.isBoost(powerUps, boostId)
		and PowerUps.isAttack(powerUps, attackId)
		and PowerUps.familyOf(powerUps, boostId) == PowerUps.familyOf(powerUps, attackId)
end

-- The effect of attack power up `id` used by a plant of `attackerLevel`,
-- changed by `boostId` when the slot carries a boost.
function PowerUps.attackEffect(
	powerUps: any,
	id: string,
	attackerLevel: number,
	boostId: string?
): AttackEffect
	assert(PowerUps.isAttack(powerUps, id), `"{id}" is not an attack power up`)
	local effect = PowerUps.effectOf(powerUps, id)
	local result: AttackEffect = {
		damageMultiplier = effect.damageMultiplier or 1,
		lockoutSeconds = (effect.lockoutSecondsPerLevel or 0) * attackerLevel,
		holdSeconds = (effect.holdSecondsPerLevel or 0) * attackerLevel,
		removeOldestPowerUp = effect.removeOldestPowerUp == true,
		sticky = effect.sticky == true,
	}
	if boostId and PowerUps.canBoost(powerUps, boostId, id) then
		local boost = PowerUps.effectOf(powerUps, boostId)
		result.lockoutSeconds *= boost.lockoutMultiplier or 1
		result.sticky = result.sticky or boost.sticky == true
		result.removeOldestPowerUp = result.removeOldestPowerUp or boost.removeOldestPowerUp == true
	end
	return result
end

-- The effect of special power up `id` used by a plant of `level`.
function PowerUps.selfEffect(powerUps: any, id: string, level: number): SelfEffect
	assert(creature(powerUps, id).kind == "special", `"{id}" is not a special power up`)
	local effect = PowerUps.effectOf(powerUps, id)
	return {
		flySeconds = (effect.flySeconds or 0) + (effect.flySecondsPerLevel or 0) * level,
		ballSeconds = effect.ballSeconds or 0,
		speedBurst = effect.speedBurst,
		speedBurstSeconds = (effect.speedBurstSecondsPerLevel or 0) * level,
		invisibleSeconds = (effect.invisibleSecondsPerLevel or 0) * level,
	}
end

-- Does defence power up `defenceId` block attack power up `attackId`?
function PowerUps.defenceBlocks(powerUps: any, defenceId: string, attackId: string): boolean
	return PowerUps.kindOf(powerUps, defenceId) == "defence"
		and PowerUps.isAttack(powerUps, attackId)
		and PowerUps.familyOf(powerUps, defenceId) == PowerUps.familyOf(powerUps, attackId)
end

-- Is a power up used up when used? Not when its slot carries a boost that
-- keeps it (mantis). Returns (usedUp, reuseSeconds).
function PowerUps.isUsedUp(powerUps: any, id: string, boostId: string?): (boolean, number)
	if boostId and PowerUps.canBoost(powerUps, boostId, id) then
		local boost = PowerUps.effectOf(powerUps, boostId)
		if boost.keepPowerUp then
			return false, boost.reuseSeconds or 0
		end
	end
	return true, 0
end

-- What a slot button shows: the family name for attacks ("Venom"), or the
-- move name for special moves ("Fly").
function PowerUps.buttonLabel(powerUps: any, id: string): string
	local info = creature(powerUps, id)
	return info.moveName or powerUps.families[info.family].name
end

return table.freeze(PowerUps)
