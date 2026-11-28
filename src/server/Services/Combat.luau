--[[
	Bites and power ups. Clients ask through the Bite and UseSlot remotes;
	NPCs call `Combat.bite` and `Combat.useSlot` directly. The server checks
	every request (cooldown, reach, protection) before anything happens.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local CreaturesConfig = require(ReplicatedStorage.Shared.Config.Creatures)
local Levels = require(ReplicatedStorage.Shared.Config.Levels)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local PlantsConfig = require(ReplicatedStorage.Shared.Config.Plants)
local PowerUpsConfig = require(ReplicatedStorage.Shared.Config.PowerUps)
local Rings = require(ReplicatedStorage.Shared.Config.Rings)
local AwardsConfig = require(ReplicatedStorage.Shared.Config.Awards)
local AwardRules = require(ReplicatedStorage.Shared.Rules.Awards)
local Aim = require(ReplicatedStorage.Shared.Rules.Aim)
local Bite = require(ReplicatedStorage.Shared.Rules.Bite)
local Growth = require(ReplicatedStorage.Shared.Rules.Growth)
local HitCheck = require(ReplicatedStorage.Shared.Rules.HitCheck)
local PowerUps = require(ReplicatedStorage.Shared.Rules.PowerUps)
local Slots = require(ReplicatedStorage.Shared.Rules.Slots)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Creatures = require(script.Parent.Creatures)
local Data = require(script.Parent.Data)
local Effects = require(script.Parent.Effects)
local Log = require(script.Parent.Log)
local MapBuilder = require(script.Parent.MapBuilder)
local Pickups = require(script.Parent.Pickups)
local PlantModel = require(script.Parent.PlantModel)
local Plants = require(script.Parent.Plants)
local Util = require(script.Parent.Util)

type Plant = Plants.Plant

local Combat = {}

local function gapTo(attacker: Plant, position: Vector3, radius: number): number
	local a = attacker.root.Position
	return HitCheck.gap(
		a.X,
		a.Y,
		a.Z,
		Plants.radius(attacker),
		position.X,
		position.Y,
		position.Z,
		radius
	)
end

-- Is there rock (or other solid map) between two points? Bites and shots
-- don't go through cliffs or cave walls.
local function rockBetween(from: Vector3, to: Vector3): boolean
	local direction = to - from
	if direction.Magnitude < 0.01 then
		return false
	end
	return workspace:Raycast(from, direction, MapBuilder.raycastParams()) ~= nil
end

-- Out of reach: too far, or with rock in the way.
local function outOfReach(
	attacker: Plant,
	position: Vector3,
	radius: number,
	reach: number
): boolean
	return gapTo(attacker, position, radius) > reach
		or rockBetween(attacker.root.Position, position)
end

local function canAct(plant: Plant, now: number): boolean
	return plant.alive
		and not plant.watchingTree
		and now - plant.spawnedAt >= PlantsConfig.spawnBiteDelay
end

-- Bites one plant by another. `multiplier` doubles damage for Slash.
-- Returns true if the bite landed.
function Combat.bitePlant(
	attacker: Plant,
	victim: Plant,
	multiplier: number?,
	cause: string?
): boolean
	local now = Plants.now()
	if victim == attacker or not victim.alive or Plants.isProtected(victim, now) then
		return false
	end
	local victimLevel = victim.level
	victim.fightStartLevels[attacker.id] = victim.fightStartLevels[attacker.id] or victimLevel
	local floor = Growth.dropFloor(Levels.list, victimLevel)
	local result = Bite.resolve(CombatConfig, attacker.level, victim.rings, floor, multiplier)
	if result.taken <= 0 then
		return false
	end
	local victimPosition = victim.root.Position
	local popped = Plants.setRings(victim, result.victimRings, cause or "bite")
	Plants.addRings(attacker, result.toBiter, "bitePlant")
	Pickups.dropNuts(victimPosition, result.toNuts)
	Effects.sound("chomp", victimPosition)

	-- Big against small: chew and toss. Levels 4 to 6 lift the victim into
	-- their mouth first and toss it the way they face.
	if not result.eaten and Bite.isChewAndToss(attacker.level, victimLevel) then
		local function toss(direction: Vector3)
			local flat = Vector3.new(direction.X, 0, direction.Z)
			flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.xAxis
			Plants.push(
				victim,
				flat * PlantsConfig.tossSpeed + Vector3.new(0, PlantsConfig.tossUpSpeed, 0)
			)
		end
		if Bite.lifts(CombatConfig, attacker.level, victimLevel) and victim.heldToken == nil then
			Plants.hold(
				victim,
				attacker,
				CombatConfig.liftSeconds,
				CombatConfig.liftHeight,
				function()
					toss(attacker.root.CFrame.LookVector)
				end
			)
		else
			toss(victimPosition - attacker.root.Position)
		end
	end

	-- Big plants stagger: a short pause and a step back from the biter.
	if not result.eaten and Bite.staggers(CombatConfig, attacker.level, victimLevel) then
		victim.holdUntil = math.max(victim.holdUntil, now + CombatConfig.staggerSeconds)
		local away = victimPosition - attacker.root.Position
		local flat = Vector3.new(away.X, 0, away.Z)
		flat = if flat.Magnitude > 0.01 then flat.Unit else -victim.root.CFrame.LookVector
		Plants.nudge(victim, flat * CombatConfig.staggerStepSpeed)
	end

	if result.droppedLevel and not result.eaten then
		victim.protectedUntil = Bite.escapeUntil(CombatConfig, now)
		if #popped > 0 and attacker.level < victimLevel then
			Data.count(attacker.player, "biggerPlantPops")
		end
	end

	if result.eaten then
		local startLevel = victim.fightStartLevels[attacker.id] or victimLevel
		Plants.addRings(attacker, Bite.eatBonus(CombatConfig, startLevel), "eatPlant")
		Effects.notify(attacker.player, `You ate {victim.name}!`, "good")
		Effects.sound("burp", attacker.root.Position)
		if startLevel >= attacker.level + AwardsConfig.giantLevelGap then
			Data.count(attacker.player, "giantsEaten")
		end
		Effects.notify(victim.player, `{attacker.name} ate you. Back to the conservatory!`, "bad")
		Log.event(victim.player, "Eaten", startLevel, `by {attacker.name}`)
		Plants.respawn(victim, "eaten")
	end
	return true
end

local function eatCreature(plant: Plant, creature: Creatures.Creature)
	Creatures.eat(creature)
	local player = plant.player
	Effects.sound("chomp", plant.root.Position)
	if creature.id == "fly" then
		local rings = Growth.flyRings(Rings, plant.rings)
		if rings == 0 then
			Effects.notify(player, "Flies are too small to fill you up now. Go hunting!", "info")
		end
		Plants.addRings(plant, rings, "fly")
		return
	end
	local info = PowerUpsConfig.creatures[creature.id]
	local rings = Growth.creatureRings(Rings, info.size, plant.fertilised, Util.roll)
	if plant.fertilised then
		plant.fertilised = false
		Effects.notify(player, `Fertilised {info.name}: +{rings} rings!`, "good")
	end
	Plants.givePowerUp(plant, creature.id)
	Plants.addRings(plant, rings, "creature")
	Data.record(player, function(progress)
		AwardRules.recordEaten(progress, creature.id)
	end)
end

-- A snap at the air: the usual wait before the next bite, and a miss effect
-- in front of the plant, toward where the player clicked.
local function miss(attacker: Plant, point: Vector3?, now: number)
	attacker.lastBiteAt = now
	local from = attacker.root.Position
	local towards = point or (from + attacker.root.CFrame.LookVector)
	local reach = Bite.reachStuds(CombatConfig, attacker.level) + Plants.radius(attacker)
	local spot = Aim.missPoint(
		{ x = from.X, y = from.Y, z = from.Z },
		{ x = towards.X, y = from.Y + Plants.scale(attacker), z = towards.Z },
		reach
	)
	local position = Vector3.new(spot.x, spot.y, spot.z)
	Effects.sendAll("miss", { position = position, scale = Plants.scale(attacker) })
	Effects.sound("miss", position)
end

-- Big plants roar first: everyone sees the head flash and hears it, then
-- after `roarSeconds` the hit lands if the victim is still in `reach` and not
-- protected; otherwise it is a miss.
local function afterRoar(attacker: Plant, victim: Plant, reach: number, land: () -> ())
	Effects.sendAll("roar", { model = attacker.model, seconds = CombatConfig.roarSeconds })
	Effects.sound("roar", attacker.root.Position)
	task.delay(CombatConfig.roarSeconds, function()
		if not attacker.alive then
			return
		end
		local inReach = victim.alive
			and victim.root.Parent ~= nil
			and not outOfReach(attacker, victim.root.Position, Plants.radius(victim), reach)
		if inReach and not Plants.isProtected(victim) then
			land()
		else
			miss(attacker, victim.root.Position, Plants.now())
		end
	end)
end

-- A bite at a target (a creature part, a cow or a plant model). With no
-- target it is a miss at `point`.
function Combat.bite(attacker: Plant, target: Instance?, point: Vector3?): boolean
	local now = Plants.now()
	if
		not canAct(attacker, now) or not Bite.canBite(CombatConfig, now, attacker.lastBiteAt, nil)
	then
		return false
	end
	local reach = Bite.reachStuds(CombatConfig, attacker.level) + PlantsConfig.hitTolerance
	-- Attacking from hiding grass gives the plant away.
	attacker.grassRevealUntil = now + Map.HidingGrass.revealSeconds

	if target == nil then
		miss(attacker, point, now)
		return false
	end

	if Creatures.isCow(target) then
		local part = target :: BasePart
		local size = math.max(part.Size.X, part.Size.Z) / 2
		if outOfReach(attacker, part.Position, size, reach) then
			return false
		end
		attacker.lastBiteAt = now
		if attacker.level < CreaturesConfig.cows.pickUpLevel then
			Effects.notify(
				attacker.player,
				`Cows are too big to pick up until level {CreaturesConfig.cows.pickUpLevel}.`,
				"info"
			)
			miss(attacker, part.Position, now)
			return false
		end
		if Creatures.pickUpCow(part, attacker.root, Plants.scale(attacker)) then
			Effects.sound("chomp", part.Position)
			return true
		end
		return false
	end

	local creature = Creatures.fromInstance(target)
	if creature then
		if outOfReach(attacker, creature.part.Position, creature.radius, reach) then
			return false
		end
		attacker.lastBiteAt = now
		eatCreature(attacker, creature)
		return true
	end

	local victim = Plants.fromModel(target)
	if victim and victim ~= attacker then
		if victim.model:GetAttribute("Invisible") == true then
			return false
		end
		if outOfReach(attacker, victim.root.Position, Plants.radius(victim), reach) then
			return false
		end
		attacker.lastBiteAt = now
		if Plants.isProtected(victim, now) then
			Effects.notify(attacker.player, `{victim.name} is safe right now.`, "info")
			return false
		end
		if Bite.roars(CombatConfig, attacker.level) then
			afterRoar(attacker, victim, reach, function()
				Combat.bitePlant(attacker, victim, 1, "bite")
			end)
			return true
		end
		return Combat.bitePlant(attacker, victim, 1, "bite")
	end
	return false
end

-- A power up attack lands on a victim. Defences and the blowfish ball can
-- stop it. Returns true if it hit at all.
function Combat.powerUpHit(attacker: Plant, victim: Plant, id: string, boost: string?): boolean
	local now = Plants.now()
	if not victim.alive or victim == attacker then
		return false
	end
	if now < victim.ballUntil then
		if attacker.level > victim.level then
			Data.count(victim.player, "blowfishEscapes")
		end
		Effects.notify(attacker.player, `{victim.name} bounced it off!`, "info")
		return false
	end
	if Plants.isProtected(victim, now) then
		return false
	end
	local effect = PowerUps.attackEffect(PowerUpsConfig, id, attacker.level, boost)
	local defenceIndex = Slots.findDefence(victim.slots, function(defenceId)
		return PowerUps.defenceBlocks(PowerUpsConfig, defenceId, id)
	end)
	local name = PowerUpsConfig.creatures[id].name
	if defenceIndex then
		local defenceId = Slots.take(victim.slots, "defence", defenceIndex)
		local defenceName = if defenceId
			then PowerUpsConfig.creatures[defenceId].name
			else "defence"
		Effects.notify(victim.player, `Your {defenceName} blocked a {name}!`, "good")
		Effects.notify(
			attacker.player,
			`{victim.name}'s {defenceName} blocked your {name}.`,
			"info"
		)
		Plants.sync(victim)
		if not CombatConfig.defenceBlocksBiteDamage then
			Combat.bitePlant(attacker, victim, 1, `blocked_{id}`)
		end
		return true
	end
	if effect.lockoutSeconds > 0 then
		victim.lockoutUntil = math.max(victim.lockoutUntil, now + effect.lockoutSeconds)
		Effects.notify(victim.player, `Venom! No power ups for {effect.lockoutSeconds} s.`, "bad")
		if effect.sticky then
			victim.stickyUntil = now + effect.lockoutSeconds
			PlantModel.setVenomSack(victim.model, true)
		end
	end
	if effect.holdSeconds > 0 then
		victim.holdUntil = math.max(victim.holdUntil, now + effect.holdSeconds)
		Effects.notify(
			victim.player,
			`Strangled! You can't move for {effect.holdSeconds} s.`,
			"bad"
		)
	end
	if effect.removeOldestPowerUp then
		local slotType, index = Slots.oldest(victim.slots)
		if slotType and index then
			local removed = Slots.take(victim.slots, slotType, index)
			if removed then
				Effects.notify(
					victim.player,
					`Acid spray melted your {PowerUpsConfig.creatures[removed].name}!`,
					"bad"
				)
			end
		end
	end
	Combat.bitePlant(attacker, victim, effect.damageMultiplier, id)
	Plants.sync(victim)
	return true
end

-- Ranged power ups fly as a ball at the projectile speed and can be dodged.
type Shot = {
	part: BasePart,
	owner: Plant,
	id: string,
	boost: string?,
	velocity: Vector3,
	travelled: number,
	range: number,
	-- Shots fired while flying home in on this plant.
	homing: Plant?,
}
local projectiles: { Shot } = {}
local projectileFolder: Folder

-- Fires at `target`, or flat toward `point` (where the player clicked), or
-- straight ahead.
local function fireProjectile(
	attacker: Plant,
	id: string,
	target: Plant?,
	boost: string?,
	point: Vector3?
)
	local start = attacker.root.Position + Vector3.new(0, 2 * Plants.scale(attacker), 0)
	local now = Plants.now()
	local flying = now < attacker.flyUntil
	local range = Bite.rangeStuds(CombatConfig, attacker.level)
	local homing: Plant? = nil
	if flying then
		range *= PlantsConfig.guideRangeMultiplier
		homing = target
		if homing == nil and point then
			-- Guided: the plant nearest the click, if one is close to it.
			local best = PlantsConfig.guideRadius
			for _, other in Plants.all() do
				local distance = (other.root.Position - point).Magnitude - Plants.radius(other)
				local hidden = other.model:GetAttribute("Invisible") == true
				if other ~= attacker and other.alive and not hidden and distance < best then
					homing, best = other, distance
				end
			end
		end
	end
	local aim = if target
		then target.root.Position
		elseif homing then homing.root.Position
		elseif point and flying then point
		elseif point then Vector3.new(point.X, start.Y, point.Z)
		else start + attacker.root.CFrame.LookVector * 10
	local direction = aim - start
	direction = if direction.Magnitude > 0.01
		then direction.Unit
		else attacker.root.CFrame.LookVector
	local creature = PowerUpsConfig.creatures[id]
	local part = Util.part({
		Name = `Projectile_{id}`,
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.2,
		Position = start,
		Color = Util.colour(PowerUpsConfig.families[creature.family].colour),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = projectileFolder,
	})
	table.insert(projectiles, {
		part = part,
		owner = attacker,
		boost = boost,
		id = id,
		velocity = direction * CombatConfig.projectileStudsPerSecond * (if homing
			then PlantsConfig.guideSpeedMultiplier
			else 1),
		travelled = 0,
		range = range,
		homing = homing,
	})
end

local function stepProjectiles(dt: number)
	local plants = Plants.all()
	for index = #projectiles, 1, -1 do
		local shot = projectiles[index]
		local homing = shot.homing
		if homing and homing.alive and homing.root.Parent then
			local towards = homing.root.Position - shot.part.Position
			if towards.Magnitude > 0.01 then
				shot.velocity = towards.Unit * shot.velocity.Magnitude
			end
		end
		local step = shot.velocity * dt
		local position = shot.part.Position + step
		local intoRock = rockBetween(shot.part.Position, position)
		shot.travelled += step.Magnitude
		shot.part.CFrame = CFrame.new(position)
		local hit: Plant? = nil
		for _, plant in plants do
			if
				plant ~= shot.owner
				and (plant.root.Position - position).Magnitude <= Plants.radius(plant) + 1.5
			then
				hit = plant
				break
			end
		end
		if intoRock then
			hit = nil
		end
		if intoRock or hit or shot.travelled >= shot.range or not shot.owner.alive then
			if hit and shot.owner.alive then
				Combat.powerUpHit(shot.owner, hit, shot.id, shot.boost)
			end
			shot.part:Destroy()
			table.remove(projectiles, index)
		end
	end
end

local function useSpecial(plant: Plant, id: string, now: number)
	local effect = PowerUps.selfEffect(PowerUpsConfig, id, plant.level)
	local name = PowerUpsConfig.creatures[id].name
	if effect.flySeconds > 0 then
		-- Shots stay guided while gliding down too.
		plant.flyUntil = now + effect.flySeconds + PlantsConfig.flyGlideMaxSeconds
		if plant.player then
			Effects.send(plant.player, "fly", { seconds = effect.flySeconds })
		else
			Plants.push(plant, Vector3.new(0, PlantsConfig.flyLiftSpeed * 2, 0))
		end
	end
	if effect.ballSeconds > 0 then
		plant.ballUntil = now + effect.ballSeconds
		PlantModel.setBall(plant.model, true)
		-- Bounce away from the nearest bigger plant (or backwards).
		local away = -plant.root.CFrame.LookVector
		local nearest = math.huge
		for _, other in Plants.all() do
			local offset = plant.root.Position - other.root.Position
			if other ~= plant and other.level > plant.level and offset.Magnitude < nearest then
				nearest = offset.Magnitude
				away = Vector3.new(offset.X, 0, offset.Z)
			end
		end
		local direction = if away.Magnitude > 0.01 then away.Unit else Vector3.xAxis
		Plants.push(plant, direction * PlantsConfig.ballBounceSpeed + Vector3.new(0, 20, 0))
	end
	if effect.speedBurstSeconds > 0 then
		plant.burstUntil = now + effect.speedBurstSeconds
	end
	if effect.invisibleSeconds > 0 then
		plant.invisibleUntil = now + effect.invisibleSeconds
		PlantModel.setInvisible(plant.model, true)
	end
	Effects.notify(plant.player, `{name}!`, "good")
	Data.record(plant.player, function(progress)
		AwardRules.recordUsed(progress, id)
	end)
end

-- Uses the power up in attack slot `index`. `target` is the clicked plant
-- (needed for melee, optional for ranged); `point` is where the player
-- clicked, which a ranged attack fires toward when there is no target.
function Combat.useSlot(plant: Plant, index: number, target: Instance?, point: Vector3?): boolean
	local now = Plants.now()
	if not canAct(plant, now) or type(index) ~= "number" then
		return false
	end
	local slot = plant.slots.attack[index]
	if slot == nil or slot.id == nil then
		return false
	end
	if now < plant.lockoutUntil then
		Effects.notify(plant.player, "Venom! You can't use power ups yet.", "bad")
		return false
	end
	if now < (plant.slotReadyAt[index] or 0) then
		return false
	end
	local id = slot.id
	local boost = slot.boost
	plant.grassRevealUntil = now + Map.HidingGrass.revealSeconds
	local kind = PowerUps.kindOf(PowerUpsConfig, id)
	local victim = Plants.fromModel(target)
	if victim == plant or (victim and victim.model:GetAttribute("Invisible") == true) then
		victim = nil
	end

	if kind == "melee" then
		local reach = Bite.reachStuds(CombatConfig, plant.level) + PlantsConfig.hitTolerance
		if
			victim == nil or outOfReach(plant, victim.root.Position, Plants.radius(victim), reach)
		then
			Effects.notify(plant.player, "Get closer to a plant to use that.", "info")
			return false
		end
		if Plants.isProtected(victim, now) then
			Effects.notify(plant.player, `{victim.name} is safe right now.`, "info")
			return false
		end
		local struck = victim :: Plant
		if Bite.roars(CombatConfig, plant.level) then
			-- Like a ranged shot, a melee hit dodged during the roar is spent.
			afterRoar(plant, struck, reach, function()
				Combat.powerUpHit(plant, struck, id, boost)
			end)
		else
			Combat.powerUpHit(plant, struck, id, boost)
		end
	elseif kind == "range" then
		local range = Bite.rangeStuds(CombatConfig, plant.level) + PlantsConfig.hitTolerance
		if victim and outOfReach(plant, victim.root.Position, Plants.radius(victim), range) then
			victim = nil
		end
		fireProjectile(plant, id, victim, boost, point)
	elseif kind == "special" then
		useSpecial(plant, id, now)
	else
		return false
	end

	-- The boost is spent with this use; a mantis keeps the power up.
	Slots.takeBoost(plant.slots, index)
	local usedUp, reuse = PowerUps.isUsedUp(PowerUpsConfig, id, boost)
	if not usedUp then
		plant.slotReadyAt[index] = now + reuse
		Effects.notify(plant.player, "Mantis kept it! Ready again in a moment.", "good")
	end
	if usedUp then
		Slots.take(plant.slots, "attack", index)
	end
	if kind ~= "special" then
		Data.record(plant.player, function(progress)
			AwardRules.recordUsed(progress, id)
		end)
	end
	Plants.sync(plant)
	return true
end

function Combat.start()
	projectileFolder = Util.folder("Projectiles")
	local function asPoint(value: any): Vector3?
		return if typeof(value) == "Vector3" then value else nil
	end
	Remotes.event("Bite").OnServerEvent:Connect(function(player, target, point)
		local plant = Plants.forPlayer(player)
		if plant and (target == nil or typeof(target) == "Instance") then
			Combat.bite(plant, target, asPoint(point))
		end
	end)
	Remotes.event("UseSlot").OnServerEvent:Connect(function(player, index, target, point)
		local plant = Plants.forPlayer(player)
		if
			plant
			and type(index) == "number"
			and (target == nil or typeof(target) == "Instance")
		then
			Combat.useSlot(plant, math.floor(index), target, asPoint(point))
		end
	end)
	RunService.Heartbeat:Connect(stepProjectiles)
end

return Combat
