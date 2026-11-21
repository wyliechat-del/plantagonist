--[[
	Bites and power ups. Clients ask through the Bite and UseSlot remotes;
	NPCs call `Combat.bite` and `Combat.useSlot` directly. The server checks
	every request (cooldown, reach, protection) before anything happens.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Levels = require(ReplicatedStorage.Shared.Config.Levels)
local PlantsConfig = require(ReplicatedStorage.Shared.Config.Plants)
local PowerUpsConfig = require(ReplicatedStorage.Shared.Config.PowerUps)
local Rings = require(ReplicatedStorage.Shared.Config.Rings)
local AwardsConfig = require(ReplicatedStorage.Shared.Config.Awards)
local AwardRules = require(ReplicatedStorage.Shared.Rules.Awards)
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

local function canAct(plant: Plant, now: number): boolean
	return plant.alive and now - plant.spawnedAt >= PlantsConfig.spawnBiteDelay
end

-- Bites one plant by another. `multiplier` doubles damage for Bite and slash.
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

	-- Big against small: chew and toss.
	if Bite.isChewAndToss(attacker.level, victimLevel) then
		local away = victimPosition - attacker.root.Position
		local flat = Vector3.new(away.X, 0, away.Z)
		local direction = if flat.Magnitude > 0.01 then flat.Unit else Vector3.xAxis
		Plants.push(
			victim,
			direction * PlantsConfig.tossSpeed + Vector3.new(0, PlantsConfig.tossUpSpeed, 0)
		)
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
		local rings = Growth.flyRings(Rings, plant.level)
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

-- A bite at a target (a creature part or a plant model).
function Combat.bite(attacker: Plant, target: Instance?): boolean
	local now = Plants.now()
	if
		not canAct(attacker, now) or not Bite.canBite(CombatConfig, now, attacker.lastBiteAt, nil)
	then
		return false
	end
	local reach = Bite.reachStuds(CombatConfig, attacker.level) + PlantsConfig.hitTolerance

	local creature = Creatures.fromInstance(target)
	if creature then
		if gapTo(attacker, creature.part.Position, creature.radius) > reach then
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
		if gapTo(attacker, victim.root.Position, Plants.radius(victim)) > reach then
			return false
		end
		attacker.lastBiteAt = now
		if Plants.isProtected(victim, now) then
			Effects.notify(attacker.player, `{victim.name} is safe right now.`, "info")
			return false
		end
		return Combat.bitePlant(attacker, victim, 1, "bite")
	end
	return false
end

-- A power up attack lands on a victim. Defences and the blowfish ball can
-- stop it. Returns true if it hit at all.
function Combat.powerUpHit(attacker: Plant, victim: Plant, id: string): boolean
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
	local effect = PowerUps.attackEffect(PowerUpsConfig, id, attacker.level)
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
local projectiles: { { part: BasePart, owner: Plant, id: string, velocity: Vector3, travelled: number, range: number } } =
	{}
local projectileFolder: Folder

local function fireProjectile(attacker: Plant, id: string, target: Plant?)
	local start = attacker.root.Position + Vector3.new(0, 2 * Plants.scale(attacker), 0)
	local aim = if target
		then target.root.Position
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
		id = id,
		velocity = direction * CombatConfig.projectileStudsPerSecond,
		travelled = 0,
		range = Bite.rangeStuds(CombatConfig, attacker.level),
	})
end

local function stepProjectiles(dt: number)
	local plants = Plants.all()
	for index = #projectiles, 1, -1 do
		local shot = projectiles[index]
		local step = shot.velocity * dt
		local position = shot.part.Position + step
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
		if hit or shot.travelled >= shot.range or not shot.owner.alive then
			if hit and shot.owner.alive then
				Combat.powerUpHit(shot.owner, hit, shot.id)
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
		plant.flyUntil = now + effect.flySeconds
		if plant.player then
			Effects.send(
				plant.player,
				"fly",
				{ seconds = effect.flySeconds, lift = PlantsConfig.flyLiftSpeed }
			)
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
	if effect.keepNextFamilyPowerUp then
		plant.keepFamily = effect.keepNextFamilyPowerUp
		Effects.notify(
			plant.player,
			"Mantis ready: your next Bite and slash power up won't be used up.",
			"good"
		)
	else
		Effects.notify(plant.player, `{name}!`, "good")
	end
	Data.record(plant.player, function(progress)
		AwardRules.recordUsed(progress, id)
	end)
end

-- Uses the power up in attack slot `index`. `target` is the aimed creature or
-- plant (needed for melee, optional for ranged).
function Combat.useSlot(plant: Plant, index: number, target: Instance?): boolean
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
	local kind = PowerUps.kindOf(PowerUpsConfig, id)
	local victim = Plants.fromModel(target)
	if victim == plant or (victim and victim.model:GetAttribute("Invisible") == true) then
		victim = nil
	end

	if kind == "melee" then
		local reach = Bite.reachStuds(CombatConfig, plant.level) + PlantsConfig.hitTolerance
		if victim == nil or gapTo(plant, victim.root.Position, Plants.radius(victim)) > reach then
			Effects.notify(plant.player, "Get closer to a plant to use that.", "info")
			return false
		end
		if Plants.isProtected(victim, now) then
			Effects.notify(plant.player, `{victim.name} is safe right now.`, "info")
			return false
		end
		Combat.powerUpHit(plant, victim, id)
	elseif kind == "range" then
		local range = Bite.rangeStuds(CombatConfig, plant.level) + PlantsConfig.hitTolerance
		if victim and gapTo(plant, victim.root.Position, Plants.radius(victim)) > range then
			victim = nil
		end
		fireProjectile(plant, id, victim)
	elseif kind == "special" then
		useSpecial(plant, id, now)
	else
		return false
	end

	local usedUp, chargeSpent = PowerUps.isUsedUp(PowerUpsConfig, id, plant.keepFamily)
	if chargeSpent then
		plant.keepFamily = nil
		local reuse = PowerUpsConfig.creatures.mantis.effect.reuseSeconds
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
	Remotes.event("Bite").OnServerEvent:Connect(function(player, target)
		local plant = Plants.forPlayer(player)
		if plant and (target == nil or typeof(target) == "Instance") then
			Combat.bite(plant, target)
		end
	end)
	Remotes.event("UseSlot").OnServerEvent:Connect(function(player, index, target)
		local plant = Plants.forPlayer(player)
		if
			plant
			and type(index) == "number"
			and (target == nil or typeof(target) == "Instance")
		then
			Combat.useSlot(plant, math.floor(index), target)
		end
	end)
	RunService.Heartbeat:Connect(stepProjectiles)
end

return Combat
