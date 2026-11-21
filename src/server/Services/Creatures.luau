--[[
	Creatures (power up carriers) by territory, flies in the field, and cows
	that drop cow poo in the Grassland.

	Creatures are single anchored parts moved by code: they wander, and run
	from plants that come close. A plant eats one by biting it (Combat).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CreaturesConfig = require(ReplicatedStorage.Shared.Config.Creatures)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local PowerUpsConfig = require(ReplicatedStorage.Shared.Config.PowerUps)
local MapRules = require(ReplicatedStorage.Shared.Rules.Map)
local Steering = require(ReplicatedStorage.Shared.Rules.Steering)

local MapBuilder = require(script.Parent.MapBuilder)
local Pickups = require(script.Parent.Pickups)
local Plants = require(script.Parent.Plants)
local Util = require(script.Parent.Util)

local Creatures = {}

export type Creature = {
	id: string, -- creature id from Config/PowerUps, or "fly"
	part: BasePart,
	territory: string, -- territory name, or "Field" for flies
	x: number,
	z: number,
	targetX: number,
	targetZ: number,
	phase: number,
	radius: number,
	alive: boolean,
}

type Cow = {
	part: BasePart,
	field: any,
	x: number,
	z: number,
	targetX: number,
	targetZ: number,
	nextPoo: number,
}

local TICK = 1 / 15
local folder: Folder
local creatures: { Creature } = {}
local byPart: { [BasePart]: Creature } = {}
local cows: { Cow } = {}
local idsByTerritory: { [string]: { string } } = {}

function Creatures.fromInstance(instance: Instance?): Creature?
	if instance == nil or not instance:IsA("BasePart") then
		return nil
	end
	local creature = byPart[instance]
	return if creature and creature.alive then creature else nil
end

function Creatures.all(): { Creature }
	return creatures
end

-- Removes an eaten creature and returns it.
function Creatures.eat(creature: Creature)
	creature.alive = false
	byPart[creature.part] = nil
	local index = table.find(creatures, creature)
	if index then
		table.remove(creatures, index)
	end
	creature.part:Destroy()
end

local function randomFieldPoint(): (number, number)
	local angle = Util.random() * math.pi * 2
	local distance = Util.random() * (Map.Field.radius - 6)
	return math.cos(angle) * distance, math.sin(angle) * distance
end

local function spawnCreature(id: string, territory: string)
	local x, z
	local size, colour, label
	if id == "fly" then
		x, z = randomFieldPoint()
		size = CreaturesConfig.flies.size
		colour = Color3.fromRGB(30, 30, 30)
		label = "Fly"
	else
		x, z = MapRules.randomPointIn(Map, territory, Util.random)
		local info = PowerUpsConfig.creatures[id]
		size = CreaturesConfig.bodySize[info.size]
		colour = Util.colour(PowerUpsConfig.families[info.family].colour)
		label = info.name
	end
	local part = Util.part({
		Name = id,
		Shape = if id == "fly" then Enum.PartType.Ball else Enum.PartType.Block,
		Size = Vector3.one * size,
		Position = Vector3.new(x, MapBuilder.groundY(x, z) + size / 2, z),
		Color = colour,
		CanCollide = false,
		CanTouch = false,
		Parent = folder,
	})
	part:SetAttribute("CreatureId", id)
	if id ~= "fly" then
		Util.label(part, label, size / 2 + 1)
	end
	local creature: Creature = {
		id = id,
		part = part,
		territory = territory,
		x = x,
		z = z,
		targetX = x,
		targetZ = z,
		phase = Util.random() * math.pi * 2,
		radius = size / 2,
		alive = true,
	}
	table.insert(creatures, creature)
	byPart[part] = creature
end

local function spawnTick()
	local counts: { [string]: number } = {}
	for _, creature in creatures do
		counts[creature.territory] = (counts[creature.territory] or 0) + 1
	end
	for territory, ids in idsByTerritory do
		if (counts[territory] or 0) < CreaturesConfig.capPerTerritory then
			spawnCreature(Util.pick(ids), territory)
		end
	end
	if (counts.Field or 0) < CreaturesConfig.flies.cap then
		spawnCreature("fly", "Field")
	end
end

local function newTarget(creature: Creature)
	local tx, tz =
		Steering.wanderTarget(creature.x, creature.z, CreaturesConfig.wanderRadius, Util.random)
	if creature.territory == "Field" then
		local distance = MapRules.distanceFromCentre(tx, tz)
		local limit = Map.Field.radius - 6
		if distance > limit then
			tx, tz = tx / distance * limit, tz / distance * limit
		end
	else
		tx, tz = MapRules.clampToTerritory(Map, creature.territory, tx, tz)
	end
	creature.targetX, creature.targetZ = tx, tz
end

local function moveTick(dt: number)
	local now = os.clock()
	local threats = {}
	for _, plant in Plants.all() do
		local position = plant.root.Position
		table.insert(threats, { x = position.X, z = position.Z })
	end
	local parts, frames = {}, {}
	for _, creature in creatures do
		local isFly = creature.id == "fly"
		local fx, fz = nil, nil
		if not isFly then
			fx, fz = Steering.fleeDirection(
				creature.x,
				creature.z,
				threats,
				CreaturesConfig.fleeDistance
			)
		end
		local oldX, oldZ = creature.x, creature.z
		if fx and fz then
			local step = CreaturesConfig.fleeSpeed * dt
			local nx, nz = creature.x + fx * step, creature.z + fz * step
			creature.x, creature.z = MapRules.clampToTerritory(Map, creature.territory, nx, nz)
			creature.targetX, creature.targetZ = creature.x, creature.z
		else
			local speed = if isFly then CreaturesConfig.flies.speed else CreaturesConfig.wanderSpeed
			local arrived
			creature.x, creature.z, arrived = Steering.moveTowards(
				creature.x,
				creature.z,
				creature.targetX,
				creature.targetZ,
				speed * dt
			)
			if arrived then
				newTarget(creature)
			end
		end
		local ground = MapBuilder.groundY(creature.x, creature.z)
		local height = if isFly
			then CreaturesConfig.flies.hoverHeight + Steering.bob(now, creature.phase, 1)
			else creature.radius + Steering.bob(now, creature.phase, creature.radius * 0.6)
		local position = Vector3.new(creature.x, ground + height, creature.z)
		local facing = Vector3.new(creature.x - oldX, 0, creature.z - oldZ)
		local frame = if facing.Magnitude > 0.01
			then CFrame.lookAt(position, position + facing)
			else creature.part.CFrame.Rotation + position
		table.insert(parts, creature.part)
		table.insert(frames, frame)
	end
	for _, cow in cows do
		local arrived
		cow.x, cow.z, arrived = Steering.moveTowards(
			cow.x,
			cow.z,
			cow.targetX,
			cow.targetZ,
			CreaturesConfig.cows.speed * dt
		)
		if arrived then
			local half = cow.field.size / 2 - 4
			cow.targetX = cow.field.x + (Util.random() * 2 - 1) * half
			cow.targetZ = cow.field.z + (Util.random() * 2 - 1) * half
		end
		if now >= cow.nextPoo then
			cow.nextPoo = now + CreaturesConfig.cows.pooEverySeconds * (0.5 + Util.random())
			Pickups.dropPoo(Vector3.new(cow.x, 0, cow.z))
		end
		local position = Vector3.new(cow.x, MapBuilder.groundY(cow.x, cow.z) + 1.75, cow.z)
		local facing = Vector3.new(cow.targetX - cow.x, 0, cow.targetZ - cow.z)
		table.insert(parts, cow.part)
		table.insert(
			frames,
			if facing.Magnitude > 0.01
				then CFrame.lookAt(position, position + facing)
				else CFrame.new(position)
		)
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function spawnCows()
	local fields = Map.Grassland.cowFields
	for index = 1, CreaturesConfig.cows.count do
		local field = fields[(index - 1) % #fields + 1]
		local part = Util.part({
			Name = "Cow",
			Size = Vector3.new(3, 3.5, 6),
			Position = Vector3.new(field.x, 2, field.z),
			Color = Color3.fromRGB(240, 240, 240),
			CanCollide = false,
			Parent = folder,
		})
		Util.label(part, "Cow", 3)
		table.insert(cows, {
			part = part,
			field = field,
			x = field.x,
			z = field.z,
			targetX = field.x,
			targetZ = field.z,
			nextPoo = os.clock() + CreaturesConfig.cows.pooEverySeconds * Util.random(),
		})
	end
end

function Creatures.start()
	folder = Util.folder("Creatures")
	for id, info in PowerUpsConfig.creatures do
		idsByTerritory[info.territory] = idsByTerritory[info.territory] or {}
		table.insert(idsByTerritory[info.territory], id)
	end
	for _, ids in idsByTerritory do
		table.sort(ids)
	end
	spawnCows()
	-- Fill the map at the start, then top up over time.
	for _ = 1, CreaturesConfig.capPerTerritory do
		spawnTick()
	end
	task.spawn(function()
		while true do
			task.wait(CreaturesConfig.spawnEverySeconds)
			spawnTick()
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= TICK then
			moveTick(elapsed)
			elapsed = 0
		end
	end)
end

return Creatures
