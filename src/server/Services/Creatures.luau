--[[
	Creatures (power up carriers) by territory, flies in the field, and cows
	that drop cow poo in the Grassland.

	Creatures are single anchored parts moved by code: they wander, and run
	from plants that come close. A plant eats one by biting it (Combat).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CreaturesConfig = require(ReplicatedStorage.Shared.Config.Creatures)
local HillsShape = require(ReplicatedStorage.Shared.Config.HillsShape)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local PowerUpsConfig = require(ReplicatedStorage.Shared.Config.PowerUps)
local MapRules = require(ReplicatedStorage.Shared.Rules.Map)
local Steering = require(ReplicatedStorage.Shared.Rules.Steering)

local Effects = require(script.Parent.Effects)
local MapBuilder = require(script.Parent.MapBuilder)
local Pickups = require(script.Parent.Pickups)
local Plants = require(script.Parent.Plants)
local Util = require(script.Parent.Util)

local Creatures = {}

export type Creature = {
	id: string, -- creature id from Config/PowerUps, or "fly"
	part: BasePart,
	territory: string, -- territory name, or "Field" for flies
	area: string, -- from MapRules.creatureArea: where it may go
	x: number,
	z: number,
	targetX: number,
	targetZ: number,
	phase: number,
	radius: number,
	alive: boolean,
	dodgeUntil: number,
	dodgeReadyAt: number,
	dodgeX: number,
	dodgeZ: number,
}

type Cow = {
	part: BasePart,
	field: any,
	-- Held by a plant until `heldUntil`, then tossed.
	holder: BasePart?,
	holderScale: number,
	heldUntil: number,
	-- While flying after a toss.
	flying: boolean,
	y: number,
	velocity: Vector3,
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

-- The cow for a part, if it is one and nobody is holding or tossing it.
local function freeCow(instance: Instance?): Cow?
	for _, cow in cows do
		if cow.part == instance then
			return if cow.holder == nil and not cow.flying then cow else nil
		end
	end
	return nil
end

function Creatures.isCow(instance: Instance?): boolean
	for _, cow in cows do
		if cow.part == instance then
			return true
		end
	end
	return false
end

-- A plant picks up a cow: it is held over `holder` for a moment, then tossed
-- the way the holder faces. Returns false if the cow is busy.
function Creatures.pickUpCow(instance: Instance?, holder: BasePart, scale: number): boolean
	local cow = freeCow(instance)
	if cow == nil then
		return false
	end
	cow.holder = holder
	cow.holderScale = scale
	cow.heldUntil = os.clock() + CreaturesConfig.cows.holdSeconds
	return true
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

-- Ground under a creature. Tunnel creatures are under the rock, so the
-- ray (which stops on top of the rock) would put them on the roof.
local function groundFor(area: string, x: number, z: number): number
	if area == "Tunnel" then
		return Map.groundY
	end
	return MapBuilder.groundY(x, z)
end

local function spawnCreature(id: string, territory: string, native: boolean)
	local x, z
	local area = MapRules.creatureArea(Map, id, native)
	local size, colour, label
	if id == "fly" then
		x, z = randomFieldPoint()
		size = CreaturesConfig.flies.size
		colour = Color3.fromRGB(30, 30, 30)
		label = "Fly"
	else
		x, z = MapRules.randomPointInArea(Map, territory, area, Util.random, HillsShape)
		local info = PowerUpsConfig.creatures[id]
		size = CreaturesConfig.bodySize[info.size]
		colour = Util.colour(PowerUpsConfig.families[info.family].colour)
		label = info.name
	end
	local part = Util.part({
		Name = id,
		Shape = if id == "fly" then Enum.PartType.Ball else Enum.PartType.Block,
		Size = Vector3.one * size,
		Position = Vector3.new(x, groundFor(area, x, z) + size / 2, z),
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
		area = area,
		x = x,
		z = z,
		targetX = x,
		targetZ = z,
		phase = Util.random() * math.pi * 2,
		radius = size / 2,
		alive = true,
		dodgeUntil = 0,
		dodgeReadyAt = 0,
		dodgeX = 0,
		dodgeZ = 0,
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
			-- Mostly native creatures, some from next door, a few from across the map.
			local source =
				MapRules.spawnSource(Map, territory, CreaturesConfig.spawnMix, Util.random)
			spawnCreature(Util.pick(idsByTerritory[source] or ids), territory, source == territory)
		end
	end
	if (counts.Field or 0) < CreaturesConfig.flies.cap then
		spawnCreature("fly", "Field", true)
	end
end

local function newTarget(creature: Creature)
	local tx, tz =
		Steering.wanderTarget(creature.x, creature.z, CreaturesConfig.wanderRadius, Util.random)
	-- Prefer a spot in the creature's own area (river, marsh, tunnel...).
	for _ = 1, CreaturesConfig.areaTargetTries do
		if
			creature.territory == "Field"
			or MapRules.creatureAllowed(creature.area, MapRules.areaAt(Map, tx, tz, HillsShape))
		then
			break
		end
		tx, tz =
			Steering.wanderTarget(creature.x, creature.z, CreaturesConfig.wanderRadius, Util.random)
	end
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
		local oldX, oldZ = creature.x, creature.z
		local oldGround = groundFor(creature.area, oldX, oldZ)
		if not isFly and now >= creature.dodgeUntil and now >= creature.dodgeReadyAt then
			-- Dodge only at the last moment, then carry on.
			local nearest, nearestDistance = nil, CreaturesConfig.dodgeDistance
			for _, threat in threats do
				local distance = math.sqrt((threat.x - oldX) ^ 2 + (threat.z - oldZ) ^ 2)
				if distance < nearestDistance then
					nearest, nearestDistance = threat, distance
				end
			end
			if nearest then
				local side = if Util.random() < 0.5 then 1 else -1
				creature.dodgeX, creature.dodgeZ =
					Steering.dodgeDirection(oldX, oldZ, nearest.x, nearest.z, side)
				creature.dodgeUntil = now + CreaturesConfig.dodgeSeconds
				creature.dodgeReadyAt = creature.dodgeUntil + CreaturesConfig.dodgeCooldown
			end
		end
		local nx, nz
		if now < creature.dodgeUntil then
			local step = CreaturesConfig.dodgeSpeed * dt
			nx, nz = creature.x + creature.dodgeX * step, creature.z + creature.dodgeZ * step
			nx, nz = MapRules.clampToTerritory(Map, creature.territory, nx, nz)
		else
			local speed = if isFly then CreaturesConfig.flies.speed else CreaturesConfig.wanderSpeed
			local arrived
			nx, nz, arrived = Steering.moveTowards(
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
		if
			not isFly
			and not MapRules.creatureAllowed(
				creature.area,
				MapRules.areaAt(Map, nx, nz, HillsShape)
			)
		then
			-- Blowfish stay in the river, toads in the marsh, bats in the
			-- tunnels, chameleons on the First Rise, the rest on land.
			nx, nz = oldX, oldZ
			creature.dodgeUntil = 0
			newTarget(creature)
		end
		local ground = groundFor(creature.area, nx, nz)
		if not isFly and ground - oldGround > CreaturesConfig.maxClimb then
			-- Too steep (a hill or wall): stay put and head somewhere else.
			nx, nz, ground = oldX, oldZ, oldGround
			creature.dodgeUntil = 0
			newTarget(creature)
		end
		creature.x, creature.z = nx, nz
		local height = if isFly
			then CreaturesConfig.flies.hoverHeight + Steering.bob(now, creature.phase, 1)
			else creature.radius
				+ Steering.bob(now, creature.phase, creature.radius * 0.6)
				+ Steering.hop(
					now - (creature.dodgeUntil - CreaturesConfig.dodgeSeconds),
					CreaturesConfig.frightHopSeconds,
					CreaturesConfig.frightHopHeight
				)
		local position = Vector3.new(creature.x, ground + height, creature.z)
		local facing = Vector3.new(creature.x - oldX, 0, creature.z - oldZ)
		local frame = if facing.Magnitude > 0.01
			then CFrame.lookAt(position, position + facing)
			else creature.part.CFrame.Rotation + position
		table.insert(parts, creature.part)
		table.insert(frames, frame)
	end
	local cowConfig = CreaturesConfig.cows
	for _, cow in cows do
		local holder = cow.holder
		if holder and holder.Parent == nil then
			cow.holder = nil
			holder = nil
			cow.flying, cow.velocity = true, Vector3.zero
			cow.y = cow.part.Position.Y
		end
		if holder then
			-- Held up in the plant's jaws, then tossed the way it faces.
			local held = holder.Position + Vector3.new(0, cowConfig.holdHeight * cow.holderScale, 0)
			cow.x, cow.y, cow.z = held.X, held.Y, held.Z
			if now >= cow.heldUntil then
				local look = holder.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.xAxis
				cow.holder = nil
				cow.flying = true
				cow.velocity = flat * cowConfig.tossSpeed + Vector3.yAxis * cowConfig.tossUpSpeed
				Effects.sound("toss", held)
			end
			table.insert(parts, cow.part)
			table.insert(
				frames,
				CFrame.new(held) * cow.part.CFrame.Rotation * CFrame.Angles(0, dt * 6, 0)
			)
			continue
		end
		if cow.flying then
			cow.velocity -= Vector3.yAxis * cowConfig.tossGravity * dt
			cow.x += cow.velocity.X * dt
			cow.z += cow.velocity.Z * dt
			cow.y += cow.velocity.Y * dt
			local ground = MapBuilder.groundY(cow.x, cow.z) + cowConfig.standHeight
			if cow.y <= ground and cow.velocity.Y < 0 then
				cow.flying = false
				cow.y = ground
				-- Walk back into its field from wherever it landed.
				local half = cow.field.size / 2 - 4
				cow.targetX = cow.field.x + (Util.random() * 2 - 1) * half
				cow.targetZ = cow.field.z + (Util.random() * 2 - 1) * half
			end
			table.insert(parts, cow.part)
			table.insert(frames, CFrame.new(cow.x, cow.y, cow.z) * CFrame.Angles(0, 0, now * 8))
			continue
		end
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
		local position =
			Vector3.new(cow.x, MapBuilder.groundY(cow.x, cow.z) + cowConfig.standHeight, cow.z)
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
			holder = nil,
			holderScale = 1,
			heldUntil = 0,
			flying = false,
			y = 0,
			velocity = Vector3.zero,
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
