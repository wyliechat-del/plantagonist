--[[
	Nuts, fruit and cow poo on the ground. A plant eats one by touching it.

	- Nut: rings (spilled from bites).
	- Fruit: a power up (popped from a lost slot, or dropped by a rooted tree)
	  plus a ring. Coloured by its power up's family.
	- Cow poo: sets the Fertiliser flag, so the next creature gives 2 to 6 rings.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Creatures = require(ReplicatedStorage.Shared.Config.Creatures)
local PickupsConfig = require(ReplicatedStorage.Shared.Config.Pickups)
local PowerUpsConfig = require(ReplicatedStorage.Shared.Config.PowerUps)

local Data = require(script.Parent.Data)
local Effects = require(script.Parent.Effects)
local MapBuilder = require(script.Parent.MapBuilder)
local Plants = require(script.Parent.Plants)
local Util = require(script.Parent.Util)

local Pickups = {}

type Pickup = { part: BasePart, kind: string, powerUp: string?, readyAt: number, expires: number }

local folder: Folder
local pickups: { Pickup } = {}

local function landingSpot(origin: Vector3): Vector3
	local angle = Util.random() * math.pi * 2
	local distance = Util.random() * PickupsConfig.scatterRadius
	local x = origin.X + math.cos(angle) * distance
	local z = origin.Z + math.sin(angle) * distance
	return Vector3.new(x, MapBuilder.groundY(x, z), z)
end

local function add(kind: string, part: BasePart, lifetime: number, powerUp: string?)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part:SetAttribute("Pickup", kind)
	part.Parent = folder
	local now = Plants.now()
	table.insert(pickups, {
		part = part,
		kind = kind,
		powerUp = powerUp,
		readyAt = now + PickupsConfig.readyDelay,
		expires = now + lifetime,
	})
end

function Pickups.dropNuts(origin: Vector3, count: number)
	for _ = 1, count do
		local spot = landingSpot(origin)
		local nut = Util.part({
			Name = "Nut",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1, 1, 1),
			Position = spot + Vector3.new(0, 0.5, 0),
			Color = Color3.fromRGB(150, 100, 50),
			Material = Enum.Material.Wood,
		})
		add("nut", nut, PickupsConfig.nutLifetime)
	end
end

function Pickups.dropFruit(origin: Vector3, powerUp: string)
	local creature = PowerUpsConfig.creatures[powerUp]
	if creature == nil then
		return
	end
	local spot = landingSpot(origin)
	local fruit = Util.part({
		Name = `Fruit_{powerUp}`,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.6, 1.6, 1.6),
		Position = spot + Vector3.new(0, 0.8, 0),
		Color = Util.colour(PowerUpsConfig.families[creature.family].colour),
		Material = Enum.Material.SmoothPlastic,
	})
	Util.label(fruit, creature.name, 1.8)
	add("fruit", fruit, PickupsConfig.fruitLifetime, powerUp)
end

-- A fruit with a random power up.
function Pickups.dropRandomFruit(origin: Vector3)
	local ids = {}
	for id in PowerUpsConfig.creatures do
		table.insert(ids, id)
	end
	table.sort(ids)
	Pickups.dropFruit(origin, Util.pick(ids))
end

function Pickups.dropPoo(origin: Vector3)
	local count = 0
	for _, pickup in pickups do
		if pickup.kind == "poo" then
			count += 1
		end
	end
	if count >= Creatures.cows.pooCap then
		return
	end
	local spot = Vector3.new(origin.X, MapBuilder.groundY(origin.X, origin.Z), origin.Z)
	local poo = Util.part({
		Name = "CowPoo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 2.2, 2.2),
		CFrame = CFrame.new(spot + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(90, 60, 30),
		Material = Enum.Material.Mud,
	})
	add("poo", poo, PickupsConfig.pooLifetime)
end

local function eat(plant: Plants.Plant, pickup: Pickup)
	local player = plant.player
	if pickup.kind == "nut" then
		Plants.addRings(plant, Combat.ringsPerNut, "nut")
		Effects.send(player, "sound", { name = "chomp" })
	elseif pickup.kind == "fruit" and pickup.powerUp then
		Plants.givePowerUp(plant, pickup.powerUp)
		Plants.addRings(plant, PickupsConfig.ringsPerFruit, "fruit")
	elseif pickup.kind == "poo" then
		plant.fertilised = true
		Plants.sync(plant)
		Effects.notify(player, "Fertilised! Your next creature gives 2 to 6 rings.", "good")
		Effects.sound("fart", plant.root.Position)
		Data.count(player, "pooEaten")
	end
end

local function step()
	local now = Plants.now()
	local plants = Plants.all()
	for index = #pickups, 1, -1 do
		local pickup = pickups[index]
		local taken = false
		if now >= pickup.expires or pickup.part.Parent == nil then
			taken = true
		elseif now >= pickup.readyAt then
			local position = pickup.part.Position
			for _, plant in plants do
				local reach = Plants.radius(plant) + PickupsConfig.touchDistance
				if Util.flatDistance(plant.root.Position, position) <= reach then
					eat(plant, pickup)
					taken = true
					break
				end
			end
		end
		if taken then
			pickup.part:Destroy()
			table.remove(pickups, index)
		end
	end
end

function Pickups.start()
	folder = Util.folder("Pickups")
	-- Power ups in lost slots pop out as fruit.
	Plants.levelChanged:connect(function(plant, _old, _new, popped)
		for _, id in popped do
			Pickups.dropFruit(plant.root.Position, id)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(PickupsConfig.checkEverySeconds)
			step()
		end
	end)
end

return Pickups
