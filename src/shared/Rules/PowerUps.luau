--[[
	What each power up does when used. Takes `Config/PowerUps.luau` as
	`powerUps`.

	Attack power ups ("melee" and "range") hit a target, do normal bite damage
	(times any `damageMultiplier`) and apply their effect. "special" power ups
	act on the user. "defence" power ups sit in defence slots and block one
	power up attack of their own family, then are used up. Defences never
	block the basic bite.
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
	keepNextFamilyPowerUp: string?, -- family whose next use isn't used up
	reuseSeconds: number,
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

function PowerUps.slotTypeFor(powerUps: any, id: string): "attack" | "defence"
	if creature(powerUps, id).kind == "defence" then
		return "defence"
	end
	return "attack"
end

function PowerUps.isAttack(powerUps: any, id: string): boolean
	local kind = creature(powerUps, id).kind
	return kind == "melee" or kind == "range"
end

-- The effect of attack power up `id` used by a plant of `attackerLevel`.
function PowerUps.attackEffect(powerUps: any, id: string, attackerLevel: number): AttackEffect
	assert(PowerUps.isAttack(powerUps, id), `"{id}" is not an attack power up`)
	local effect = PowerUps.effectOf(powerUps, id)
	return {
		damageMultiplier = effect.damageMultiplier or 1,
		lockoutSeconds = (effect.lockoutSecondsPerLevel or 0) * attackerLevel,
		holdSeconds = (effect.holdSecondsPerLevel or 0) * attackerLevel,
		removeOldestPowerUp = effect.removeOldestPowerUp == true,
		sticky = effect.sticky == true,
	}
end

-- The effect of special power up `id` used by a plant of `level`.
function PowerUps.selfEffect(powerUps: any, id: string, level: number): SelfEffect
	assert(creature(powerUps, id).kind == "special", `"{id}" is not a special power up`)
	local effect = PowerUps.effectOf(powerUps, id)
	return {
		flySeconds = (effect.flySecondsPerLevel or 0) * level,
		ballSeconds = effect.ballSeconds or 0,
		speedBurst = effect.speedBurst,
		speedBurstSeconds = (effect.speedBurstSecondsPerLevel or 0) * level,
		invisibleSeconds = (effect.invisibleSecondsPerLevel or 0) * level,
		keepNextFamilyPowerUp = if effect.keepNextFamilyPowerUp
			then PowerUps.familyOf(powerUps, id)
			else nil,
		reuseSeconds = effect.reuseSeconds or 0,
	}
end

-- Does defence power up `defenceId` block attack power up `attackId`?
function PowerUps.defenceBlocks(powerUps: any, defenceId: string, attackId: string): boolean
	return PowerUps.kindOf(powerUps, defenceId) == "defence"
		and PowerUps.isAttack(powerUps, attackId)
		and PowerUps.familyOf(powerUps, defenceId) == PowerUps.familyOf(powerUps, attackId)
end

-- Is an attack power up used up when used? Not when a mantis charge for its
-- family is active (`keepFamily`). Returns (usedUp, chargeSpent).
function PowerUps.isUsedUp(powerUps: any, id: string, keepFamily: string?): (boolean, boolean)
	if
		keepFamily ~= nil
		and PowerUps.isAttack(powerUps, id)
		and PowerUps.familyOf(powerUps, id) == keepFamily
	then
		return false, true
	end
	return true, false
end

return table.freeze(PowerUps)
