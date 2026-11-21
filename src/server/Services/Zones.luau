--[[
	Runs a few times a second for every plant: keeps big plants out of the
	safe field, gives spawn protection on leaving it, sets walking speed
	(level, swamp, river, strangle, speed burst) and ends timed effects.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Levels = require(ReplicatedStorage.Shared.Config.Levels)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local PlantsConfig = require(ReplicatedStorage.Shared.Config.Plants)
local PowerUpsConfig = require(ReplicatedStorage.Shared.Config.PowerUps)
local Growth = require(ReplicatedStorage.Shared.Rules.Growth)
local MapRules = require(ReplicatedStorage.Shared.Rules.Map)

local Effects = require(script.Parent.Effects)
local MapBuilder = require(script.Parent.MapBuilder)
local PlantModel = require(script.Parent.PlantModel)
local Plants = require(script.Parent.Plants)

local Zones = {}

local TICK = 0.1

local function isRaised(plant: Plants.Plant): boolean
	local origin = plant.root.Position
	local result = workspace:Raycast(
		origin,
		Vector3.new(0, -8 * Plants.scale(plant), 0),
		MapBuilder.raycastParams()
	)
	if result == nil then
		return false
	end
	local maxLevel = result.Instance:GetAttribute("RaisedMaxLevel")
	return type(maxLevel) == "number" and plant.level <= maxLevel
end

local function walkSpeed(plant: Plants.Plant, now: number): number
	if now < plant.holdUntil then
		return 0
	end
	if now < plant.burstUntil then
		local burst = PowerUpsConfig.creatures.centipede.effect.speedBurst
		return burst * Levels.studsPerSpeedUnit
	end
	local base = Growth.studsPerSecond(Levels.list, Levels.studsPerSpeedUnit, plant.level)
	local position = plant.root.Position
	return base * MapRules.speedFactor(Map, plant.level, position.X, position.Z, isRaised(plant))
end

local function step()
	local now = Plants.now()
	for _, plant in Plants.all() do
		local position = plant.root.Position
		local inField = MapRules.inField(Map, position.X, position.Z)
		if inField and not MapRules.canBeInField(Map, plant.level) then
			local x, z = MapRules.pushOut(Map, position.X, position.Z)
			Plants.teleport(
				plant,
				Vector3.new(x, MapBuilder.groundY(x, z) + 3 * Plants.scale(plant), z)
			)
			Effects.notify(plant.player, "You're too big for the safe field now.", "info")
			inField = false
		end
		if plant.inField and not inField then
			plant.protectedUntil =
				math.max(plant.protectedUntil, now + CombatConfig.spawnProtectionSeconds)
		end
		plant.inField = inField

		local speed = walkSpeed(plant, now)
		if math.abs(plant.humanoid.WalkSpeed - speed) > 0.05 then
			plant.humanoid.WalkSpeed = speed
		end
		local jump = if now < plant.holdUntil then 0 else PlantsConfig.jumpHeight
		if plant.humanoid.JumpHeight ~= jump then
			plant.humanoid.JumpHeight = jump
		end

		local model = plant.model
		if model:GetAttribute("Invisible") == true and now >= plant.invisibleUntil then
			PlantModel.setInvisible(model, false)
		end
		if plant.ballUntil > 0 and now >= plant.ballUntil then
			plant.ballUntil = 0
			PlantModel.setBall(model, false)
		end
		if plant.stickyUntil > 0 and now >= plant.stickyUntil then
			plant.stickyUntil = 0
			PlantModel.setVenomSack(model, false)
		end
		local protected = Plants.isProtected(plant, now)
		if model:GetAttribute("Protected") ~= protected then
			model:SetAttribute("Protected", protected)
		end
	end
end

function Zones.start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			step()
		end
	end)
end

return Zones
