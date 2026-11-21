--[[
	Every plant in the game (players and NPCs) and its state: rings, level,
	power up slots and effect timers. Other services change plants through
	these functions so levels, slots, looks and the HUD stay in step.

	Times are `workspace:GetServerTimeNow()` seconds, which clients can read
	too.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Levels = require(ReplicatedStorage.Shared.Config.Levels)
local PlantsConfig = require(ReplicatedStorage.Shared.Config.Plants)
local PowerUpsConfig = require(ReplicatedStorage.Shared.Config.PowerUps)
local Npc = require(ReplicatedStorage.Shared.Config.Npc)
local Growth = require(ReplicatedStorage.Shared.Rules.Growth)
local PowerUps = require(ReplicatedStorage.Shared.Rules.PowerUps)
local Slots = require(ReplicatedStorage.Shared.Rules.Slots)

local Data = require(script.Parent.Data)
local Effects = require(script.Parent.Effects)
local Log = require(script.Parent.Log)
local MapBuilder = require(script.Parent.MapBuilder)
local PlantModel = require(script.Parent.PlantModel)
local Util = require(script.Parent.Util)

local Plants = {}

export type Plant = {
	id: number,
	name: string,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	player: Player?,
	isNpc: boolean,
	alive: boolean,
	rings: number,
	level: number,
	slots: Slots.Slots,
	slotReadyAt: { [number]: number },
	lastBiteAt: number?,
	spawnedAt: number,
	protectedUntil: number,
	lockoutUntil: number,
	holdUntil: number,
	-- Set while another plant holds this one in its mouth.
	heldToken: {}?,
	flyUntil: number,
	ballUntil: number,
	burstUntil: number,
	invisibleUntil: number,
	stickyUntil: number,
	fertilised: boolean,
	inField: boolean,
	droppedSinceSpawn: boolean,
	fightStartLevels: { [number]: number },
}

-- Fired as (plant, oldLevel, newLevel, poppedPowerUpIds, cause).
Plants.levelChanged = Util.signal()
-- Fired as (plant, reason) after a plant respawns.
Plants.respawned = Util.signal()

local byModel: { [Model]: Plant } = {}
local byPlayer: { [Player]: Plant } = {}
local nextId = 1

function Plants.now(): number
	return workspace:GetServerTimeNow()
end

function Plants.all(): { Plant }
	local list = {}
	for _, plant in byModel do
		if plant.alive then
			table.insert(list, plant)
		end
	end
	return list
end

function Plants.fromModel(model: Instance?): Plant?
	if model == nil or not model:IsA("Model") then
		return nil
	end
	local plant = byModel[model]
	return if plant and plant.alive then plant else nil
end

function Plants.forPlayer(player: Player): Plant?
	local plant = byPlayer[player]
	return if plant and plant.alive then plant else nil
end

function Plants.scale(plant: Plant): number
	return PlantsConfig.scaleByLevel[plant.level]
end

function Plants.radius(plant: Plant): number
	return PlantsConfig.radiusAtScale1 * Plants.scale(plant)
end

function Plants.position(plant: Plant): Vector3
	return plant.root.Position
end

-- The most rings this plant may hold (NPCs stop below rooting).
function Plants.maxRings(plant: Plant): number
	if plant.isNpc then
		local next = Levels.list[Npc.maxLevel + 1]
		return if next then next.minRings - 1 else Levels.rootRings - 1
	end
	return Levels.rootRings
end

function Plants.isProtected(plant: Plant, now: number?): boolean
	local t = now or Plants.now()
	return plant.inField or t < plant.protectedUntil or t < plant.ballUntil
end

local function slotIds(plant: Plant): { string }
	local ids = {}
	for _, list in { plant.slots.attack, plant.slots.defence } do
		for _, slot in list do
			if slot.id then
				table.insert(ids, slot.id)
			end
			if slot.boost then
				table.insert(ids, slot.boost)
			end
		end
	end
	return ids
end

-- Copies state to attributes the client HUD reads, and refreshes the look.
function Plants.sync(plant: Plant)
	local info = Levels.list[plant.level]
	local model = plant.model
	model:SetAttribute("PlantId", plant.id)
	model:SetAttribute("PlantLevel", plant.level)
	model:SetAttribute("Protected", Plants.isProtected(plant))
	PlantModel.setLabel(model, `{plant.name}\n{info.name}`)
	PlantModel.showPowerUps(model, slotIds(plant))
	local player = plant.player
	if player == nil then
		return
	end
	player:SetAttribute("Rings", plant.rings)
	player:SetAttribute("Level", plant.level)
	player:SetAttribute("LevelName", info.name)
	player:SetAttribute("AttackSlots", #plant.slots.attack)
	player:SetAttribute("DefenceSlots", #plant.slots.defence)
	for index = 1, 3 do
		local slot = plant.slots.attack[index]
		player:SetAttribute(`Attack{index}`, if slot and slot.id then slot.id else "")
		player:SetAttribute(`Attack{index}ReadyAt`, plant.slotReadyAt[index] or 0)
		player:SetAttribute(`Attack{index}Boost`, if slot and slot.boost then slot.boost else "")
	end
	for index = 1, 2 do
		local slot = plant.slots.defence[index]
		player:SetAttribute(`Defence{index}`, if slot and slot.id then slot.id else "")
	end
	player:SetAttribute("Fertilised", plant.fertilised)
	player:SetAttribute("LockoutUntil", plant.lockoutUntil)
	local stats = player:FindFirstChild("leaderstats")
	local rings = stats and stats:FindFirstChild("Rings") :: IntValue?
	if rings then
		rings.Value = plant.rings
	end
end

local function applyScale(plant: Plant)
	local scale = Plants.scale(plant)
	if math.abs(plant.model:GetScale() - scale) > 0.001 then
		plant.model:ScaleTo(scale)
	end
end

-- Sets a plant's rings, handling level ups and level drops. Returns the
-- power ups that popped out of lost slots.
function Plants.setRings(plant: Plant, rings: number, cause: string): { string }
	local now = Plants.now()
	plant.rings = math.clamp(math.floor(rings), 0, Plants.maxRings(plant))
	local oldLevel = plant.level
	local newLevel = Growth.levelFor(Levels.list, plant.rings)
	local popped = {}
	if newLevel ~= oldLevel then
		plant.level = newLevel
		local info = Levels.list[newLevel]
		popped = Slots.resize(plant.slots, info.attackSlots, info.defenceSlots)
		applyScale(plant)
		local player = plant.player
		if newLevel > oldLevel then
			Effects.notify(player, `You grew into a {info.name}!`, "good")
			Effects.send(player, "sound", { name = "levelUp" })
			Log.event(player, `ReachedLevel{newLevel}`, math.floor(now - plant.spawnedAt), cause)
			if newLevel == #Levels.list then
				Data.count(player, "reachedTopLevel")
				if not plant.droppedSinceSpawn then
					Data.count(player, "untouchable")
				end
			end
		else
			plant.droppedSinceSpawn = true
			Effects.notify(player, `You shrank to a {info.name}!`, "bad")
			Effects.sound("levelDown", Plants.position(plant))
			Log.event(player, "LevelDrop", newLevel, `cause={cause}`)
		end
		Plants.levelChanged:fire(plant, oldLevel, newLevel, popped, cause)
	end
	Plants.sync(plant)
	return popped
end

function Plants.addRings(plant: Plant, amount: number, cause: string)
	if amount == 0 then
		return
	end
	Plants.setRings(plant, plant.rings + amount, cause)
end

-- Puts a power up into a slot of the right type. Returns true if it was kept.
function Plants.givePowerUp(plant: Plant, id: string): boolean
	local slotType = PowerUps.slotTypeFor(PowerUpsConfig, id)
	local name = PowerUpsConfig.creatures[id].name
	if slotType == "boost" then
		-- Boosts ride on a loaded attack of their family, or are lost.
		local boosted = Slots.addBoost(plant.slots, id, function(attackId)
			return PowerUps.canBoost(PowerUpsConfig, id, attackId)
		end)
		local familyName = PowerUpsConfig.families[PowerUpsConfig.creatures[id].family].name
		if boosted == nil then
			Effects.notify(plant.player, `{name} needs a {familyName} attack.`, "info")
			return false
		end
		Effects.notify(plant.player, `{name} boosted your {familyName} attack!`, "good")
		Effects.send(plant.player, "sound", { name = "powerUp" })
		Plants.sync(plant)
		return true
	end
	local index, replaced = Slots.add(plant.slots, slotType, id)
	if index == nil then
		Effects.notify(
			plant.player,
			`No {slotType} slot yet, so the {name} just gave rings.`,
			"info"
		)
		return false
	end
	if slotType == "attack" then
		plant.slotReadyAt[index] = 0
	end
	local text = if replaced
		then `{name} replaced your {PowerUpsConfig.creatures[replaced].name}.`
		else `{name} power up loaded.`
	Effects.notify(plant.player, text, "info")
	Effects.send(plant.player, "sound", { name = "powerUp" })
	Plants.sync(plant)
	return true
end

-- Moves a plant to a spot (keeps it upright).
function Plants.teleport(plant: Plant, position: Vector3)
	plant.model:PivotTo(CFrame.new(position))
end

-- Pushes a plant with a velocity. Player characters are moved by their own
-- client, so the push is sent there.
function Plants.push(plant: Plant, velocity: Vector3)
	if plant.player then
		Effects.send(plant.player, "push", { velocity = velocity })
	else
		plant.root.AssemblyLinearVelocity = velocity
	end
end

-- Holds a plant in another plant's mouth for `seconds`, then calls
-- `release`. The victim's root is anchored and moved by the server meanwhile.
-- Stops early if either plant dies or leaves.
function Plants.hold(
	victim: Plant,
	holder: Plant,
	seconds: number,
	height: number,
	release: () -> ()
)
	local root = victim.root
	local token = {}
	victim.heldToken = token
	root.Anchored = true
	local untilAt = os.clock() + seconds
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local done = os.clock() >= untilAt
			or victim.heldToken ~= token
			or not victim.alive
			or not holder.alive
			or root.Parent == nil
			or holder.root.Parent == nil
		if not done then
			local mouth = holder.root.CFrame
				* CFrame.new(0, height * Plants.scale(holder), -Plants.radius(holder))
			victim.model:PivotTo(mouth)
			return
		end
		connection:Disconnect()
		local stillHeld = victim.heldToken == token
		if stillHeld then
			victim.heldToken = nil
			if root.Parent then
				root.Anchored = false
			end
		end
		if stillHeld and victim.alive and holder.alive then
			release()
		end
	end)
end

local function resetTimers(plant: Plant, now: number)
	plant.lastBiteAt = now - 10
	plant.spawnedAt = now
	plant.protectedUntil = now
	plant.lockoutUntil = 0
	plant.holdUntil = 0
	plant.flyUntil = 0
	plant.ballUntil = 0
	plant.burstUntil = 0
	plant.invisibleUntil = 0
	plant.stickyUntil = 0
	plant.fertilised = false
	plant.droppedSinceSpawn = false
	plant.fightStartLevels = {}
	plant.slotReadyAt = {}
end

-- Starts a plant again as a Seedling. It keeps its latest attack power up.
function Plants.respawn(plant: Plant, reason: string, position: Vector3?)
	local now = Plants.now()
	local kept = Slots.latestAttack(plant.slots)
	local first = Levels.list[1]
	plant.slots = Slots.new(first.attackSlots, first.defenceSlots)
	if kept then
		Slots.add(plant.slots, "attack", kept)
	end
	resetTimers(plant, now)
	-- Let go if another plant was holding it.
	plant.heldToken = nil
	plant.root.Anchored = false
	plant.rings = Levels.respawnRings
	plant.level = 1
	applyScale(plant)
	PlantModel.setInvisible(plant.model, false)
	PlantModel.setBall(plant.model, false)
	PlantModel.setVenomSack(plant.model, false)
	Plants.teleport(plant, position or MapBuilder.spawnPosition())
	Plants.sync(plant)
	Plants.respawned:fire(plant, reason)
end

-- Starts tracking a character as a plant.
function Plants.register(model: Model, player: Player?, name: string): Plant?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or root == nil then
		warn(`[Plants] {model.Name} has no Humanoid or HumanoidRootPart`)
		return nil
	end
	PlantModel.dress(model)
	local first = Levels.list[1]
	local plant: Plant = {
		id = nextId,
		name = name,
		model = model,
		humanoid = humanoid,
		root = root,
		player = player,
		isNpc = player == nil,
		alive = true,
		rings = Levels.respawnRings,
		level = 1,
		slots = Slots.new(first.attackSlots, first.defenceSlots),
		slotReadyAt = {},
		lastBiteAt = nil,
		spawnedAt = 0,
		protectedUntil = 0,
		lockoutUntil = 0,
		holdUntil = 0,
		flyUntil = 0,
		ballUntil = 0,
		burstUntil = 0,
		invisibleUntil = 0,
		stickyUntil = 0,
		fertilised = false,
		inField = false,
		droppedSinceSpawn = false,
		fightStartLevels = {},
	}
	nextId += 1
	resetTimers(plant, Plants.now())
	byModel[model] = plant
	if player then
		byPlayer[player] = plant
	end
	applyScale(plant)
	Plants.sync(plant)
	humanoid.Died:Connect(function()
		Plants.unregister(plant)
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			Plants.unregister(plant)
		end
	end)
	return plant
end

function Plants.unregister(plant: Plant)
	if not plant.alive then
		return
	end
	plant.alive = false
	byModel[plant.model] = nil
	if plant.player and byPlayer[plant.player] == plant then
		byPlayer[plant.player] = nil
	end
end

local function makeLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local trees = Instance.new("IntValue")
	trees.Name = "Trees"
	trees.Parent = stats
	local rings = Instance.new("IntValue")
	rings.Name = "Rings"
	rings.Parent = stats
	stats.Parent = player
end

function Plants.start()
	local function onPlayer(player: Player)
		makeLeaderstats(player)
		player:SetAttribute("JoinedAt", Plants.now())
		player.CharacterAdded:Connect(function(character)
			-- Wait for the body parts to arrive before dressing it.
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Humanoid", 10)
			task.wait()
			local plant = Plants.register(character, player, player.DisplayName)
			if plant then
				Plants.teleport(plant, MapBuilder.spawnPosition())
				Plants.respawned:fire(plant, "joined")
			end
		end)
		if player.Character then
			task.spawn(function()
				local plant = Plants.register(player.Character :: Model, player, player.DisplayName)
				if plant then
					Plants.respawned:fire(plant, "joined")
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local joined = player:GetAttribute("JoinedAt")
		if type(joined) == "number" then
			Log.event(player, "SessionEnd", math.floor(Plants.now() - joined))
		end
		local plant = byPlayer[player]
		if plant then
			Plants.unregister(plant)
		end
	end)
end

return Plants
