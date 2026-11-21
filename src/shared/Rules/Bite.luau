--[[
	Plant on plant bites.

	A bite takes `ringsPerAttackerLevel * attackerLevel * multiplier` rings, but
	never takes the victim down more than one level: damage stops at the drop.
	Part of what is taken goes to the biter, the rest spills as nuts.

	Takes `Config/Combat.luau` as `combat`. The caller works out `victimFloor`
	with `Growth.dropFloor` (Rules modules don't require each other).
]]

local Bite = {}

export type BiteResult = {
	taken: number, -- rings removed from the victim
	toBiter: number, -- rings the biter gains straight away
	toNuts: number, -- rings spilled on the ground as nuts
	victimRings: number, -- the victim's rings after the bite
	droppedLevel: boolean, -- true when the bite reached the floor of the victim's level
	eaten: boolean, -- true when the victim reached 0 rings
}

function Bite.damage(combat: any, attackerLevel: number, multiplier: number?): number
	return combat.ringsPerAttackerLevel * attackerLevel * (multiplier or 1)
end

-- `victimFloor` is the ring count the victim drops to when it loses a level.
function Bite.resolve(
	combat: any,
	attackerLevel: number,
	victimRings: number,
	victimFloor: number,
	multiplier: number?
): BiteResult
	local room = math.max(victimRings - victimFloor, 0)
	local taken = math.min(Bite.damage(combat, attackerLevel, multiplier), room)
	local toBiter = math.ceil(taken * combat.biterShare)
	local after = victimRings - taken
	return {
		taken = taken,
		toBiter = toBiter,
		toNuts = taken - toBiter,
		victimRings = after,
		droppedLevel = taken > 0 and after <= victimFloor,
		eaten = after <= 0,
	}
end

-- Bonus for eating a plant. `victimLevel` is the level the victim had when
-- this attacker first bit it, since every plant is level 1 when it's eaten.
function Bite.eatBonus(combat: any, victimLevel: number): number
	return combat.eatBonusPerVictimLevel * victimLevel
end

-- Bigger plants pick smaller ones up, chew and toss them. Smaller ones peck.
function Bite.isChewAndToss(attackerLevel: number, victimLevel: number): boolean
	return attackerLevel > victimLevel
end

-- Can `now` be a bite? Checks the biter's cooldown and the victim's
-- protection (escape moment or spawn protection) timers.
function Bite.canBite(
	combat: any,
	now: number,
	lastBiteAt: number?,
	victimProtectedUntil: number?
): boolean
	if lastBiteAt and now - lastBiteAt < combat.biteCooldown then
		return false
	end
	if victimProtectedUntil and now < victimProtectedUntil then
		return false
	end
	return true
end

-- When a victim who just dropped a level stops being protected.
function Bite.escapeUntil(combat: any, now: number): number
	return now + combat.escapeSeconds
end

function Bite.reachStuds(combat: any, level: number): number
	return combat.biteReachBaseStuds + combat.biteReachStudsPerLevel * level
end

function Bite.rangeStuds(combat: any, level: number): number
	return combat.rangeBaseStuds + combat.rangeStudsPerLevel * level
end

-- Seconds a projectile takes to cover `distance` studs.
function Bite.flightSeconds(combat: any, distance: number): number
	return distance / combat.projectileStudsPerSecond
end

return table.freeze(Bite)
