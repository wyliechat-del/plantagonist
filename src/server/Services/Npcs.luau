--[[
	NPC plants so a playtest with 3 or 4 people still feels busy (and the start
	of a solo mode). The server keeps players plus NPCs at `Npc.targetPlants`.
	NPCs wander, eat creatures, hunt smaller plants and flee bigger ones.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local NpcConfig = require(ReplicatedStorage.Shared.Config.Npc)
local PlantsConfig = require(ReplicatedStorage.Shared.Config.Plants)
local PowerUpsConfig = require(ReplicatedStorage.Shared.Config.PowerUps)
local Rings = require(ReplicatedStorage.Shared.Config.Rings)
local Bite = require(ReplicatedStorage.Shared.Rules.Bite)
local MapRules = require(ReplicatedStorage.Shared.Rules.Map)
local NpcRules = require(ReplicatedStorage.Shared.Rules.Npc)
local PowerUps = require(ReplicatedStorage.Shared.Rules.PowerUps)

local Combat = require(script.Parent.Combat)
local Creatures = require(script.Parent.Creatures)
local MapBuilder = require(script.Parent.MapBuilder)
local Plants = require(script.Parent.Plants)
local Util = require(script.Parent.Util)

local Npcs = {}

type Brain = { plant: Plants.Plant, wanderX: number?, wanderZ: number? }

local folder: Folder
local brains: { Brain } = {}
local nameIndex = 0

local function territoryNames(): { string }
	local names = {}
	for name in Map.territories do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local function spawnNpc()
	nameIndex += 1
	local name = NpcConfig.names[(nameIndex - 1) % #NpcConfig.names + 1]
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(
			Instance.new("HumanoidDescription"),
			Enum.HumanoidRigType.R15
		)
	end)
	if not ok or model == nil then
		warn(`[Npcs] couldn't make an NPC: {model}`)
		return
	end
	model.Name = name
	local x, z = MapRules.randomPointIn(Map, Util.pick(territoryNames()), Util.random)
	model:PivotTo(CFrame.new(x, MapBuilder.groundY(x, z) + 4, z))
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	local plant = Plants.register(model, nil, name)
	if plant then
		Plants.sync(plant)
		table.insert(brains, { plant = plant })
	else
		model:Destroy()
	end
end

local function seen(brain: Brain): ({ NpcRules.Seen }, { NpcRules.Seen })
	local me = brain.plant
	local position = me.root.Position
	local plants, creatures = {}, {}
	for _, other in Plants.all() do
		if other ~= me and other.model:GetAttribute("Invisible") ~= true then
			local there = other.root.Position
			if Util.flatDistance(position, there) <= NpcConfig.sightDistance then
				-- Protected plants can still scare an NPC, but aren't worth hunting.
				local level = other.level
				if Plants.isProtected(other) and level < me.level then
					level = me.level
				end
				table.insert(plants, { key = other, level = level, x = there.X, z = there.Z })
			end
		end
	end
	for _, creature in Creatures.all() do
		local there = creature.part.Position
		local isFly = creature.id == "fly"
		local usable = if isFly then me.rings < Rings.fliesMaxRings else true
		if usable and Util.flatDistance(position, there) <= NpcConfig.sightDistance then
			local inField = MapRules.inField(Map, there.X, there.Z)
			if not inField or MapRules.canBeInField(Map, me.level) then
				table.insert(creatures, { key = creature, x = there.X, z = there.Z })
			end
		end
	end
	return plants, creatures
end

local function loadedAttack(plant: Plants.Plant, kinds: { [string]: boolean }): number?
	for index, slot in plant.slots.attack do
		if slot.id and kinds[PowerUps.kindOf(PowerUpsConfig, slot.id)] then
			return index
		end
	end
	return nil
end

local function think(brain: Brain)
	local me = brain.plant
	local position = me.root.Position
	local plants, creatures = seen(brain)
	local action = NpcRules.decide(
		NpcConfig,
		{ level = me.level, x = position.X, z = position.Z },
		plants,
		creatures
	)
	local humanoid = me.humanoid
	local reach = Bite.reachStuds(CombatConfig, me.level)
		+ Plants.radius(me)
		+ PlantsConfig.hitTolerance / 2

	if action.kind == "flee" then
		local threat = action.key :: Plants.Plant
		local away = position - threat.root.Position
		local flat = Vector3.new(away.X, 0, away.Z)
		local direction = if flat.Magnitude > 0.01 then flat.Unit else Vector3.xAxis
		humanoid:MoveTo(position + direction * 30)
		local special = loadedAttack(me, { special = true })
		if special and Util.random() < NpcConfig.powerUpChance then
			Combat.useSlot(me, special, nil)
		end
	elseif action.kind == "hunt" then
		local prey = action.key :: Plants.Plant
		local there = prey.root.Position
		humanoid:MoveTo(there)
		local distance = (there - position).Magnitude - Plants.radius(prey)
		local attack = loadedAttack(me, { melee = true, range = true })
		if attack and Util.random() < NpcConfig.powerUpChance then
			local kind = PowerUps.kindOf(PowerUpsConfig, me.slots.attack[attack].id :: string)
			local limit = if kind == "range" then Bite.rangeStuds(CombatConfig, me.level) else reach
			if distance <= limit then
				Combat.useSlot(me, attack, prey.model)
				return
			end
		end
		if distance <= reach then
			Combat.bite(me, prey.model)
		end
	elseif action.kind == "eat" then
		local creature = action.key :: Creatures.Creature
		local there = creature.part.Position
		humanoid:MoveTo(there)
		if (there - position).Magnitude - creature.radius <= reach then
			Combat.bite(me, creature.part)
		end
	else
		local wx, wz = brain.wanderX, brain.wanderZ
		if wx == nil or wz == nil or Util.flatDistance(position, Vector3.new(wx, 0, wz)) < 6 then
			local territory = MapRules.territoryAt(Map, position.X, position.Z)
			if territory == "Field" then
				territory = Util.pick(territoryNames())
			end
			wx, wz = MapRules.randomPointIn(Map, territory, Util.random)
			brain.wanderX, brain.wanderZ = wx, wz
		end
		humanoid:MoveTo(Vector3.new(wx :: number, position.Y, wz :: number))
	end
end

local function balance()
	for index = #brains, 1, -1 do
		local brain = brains[index]
		if not brain.plant.alive then
			if brain.plant.model.Parent then
				brain.plant.model:Destroy()
			end
			table.remove(brains, index)
		end
	end
	local wanted = math.max(0, NpcConfig.targetPlants - #Players:GetPlayers())
	if #brains < wanted then
		spawnNpc()
	elseif #brains > wanted then
		local brain = table.remove(brains) :: Brain
		Plants.unregister(brain.plant)
		brain.plant.model:Destroy()
	end
end

function Npcs.start()
	folder = Util.folder("NPCs")
	task.spawn(function()
		while true do
			balance()
			task.wait(2)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(NpcConfig.thinkEverySeconds)
			for _, brain in brains do
				if brain.plant.alive then
					local ok, err = pcall(think, brain)
					if not ok then
						warn(`[Npcs] {err}`)
					end
				end
			end
		end
	end)
end

return Npcs
