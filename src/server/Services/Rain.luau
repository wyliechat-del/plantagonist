--[[
	Rain clouds: every 1 to 2 minutes a dark shadow appears over one
	territory and shrinks to a small cloud, which rains for a few seconds.
	Touching the rain gives rings per level, once per cloud.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local Rings = require(ReplicatedStorage.Shared.Config.Rings)
local Growth = require(ReplicatedStorage.Shared.Rules.Growth)
local MapRules = require(ReplicatedStorage.Shared.Rules.Map)

local Data = require(script.Parent.Data)
local Effects = require(script.Parent.Effects)
local MapBuilder = require(script.Parent.MapBuilder)
local Plants = require(script.Parent.Plants)
local Util = require(script.Parent.Util)

local Rain = {}

local Rule = Environment.Rain
local folder: Folder

local function disc(
	name: string,
	radius: number,
	y: number,
	x: number,
	z: number,
	colour: Color3,
	transparency: number
)
	return Util.part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = colour,
		Transparency = transparency,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})
end

local function oneCloud()
	local territories = {}
	for name in Map.territories do
		table.insert(territories, name)
	end
	table.sort(territories)
	local territory = Util.pick(territories)
	local x, z = MapRules.randomPointIn(Map, territory, Util.random)
	local ground = MapBuilder.groundY(x, z)
	Effects.notifyAll(`Rain is coming to the {territory}!`, "event")

	local shadow =
		disc("RainShadow", Rule.shadowStartRadius, ground + 0.4, x, z, Color3.new(0, 0, 0), 0.5)
	local small = Vector3.new(0.3, Rule.cloudRadius * 2, Rule.cloudRadius * 2)
	local tween = TweenService:Create(
		shadow,
		TweenInfo.new(Rule.shadowSeconds, Enum.EasingStyle.Linear),
		{ Size = small }
	)
	tween:Play()
	tween.Completed:Wait()

	local cloud = Util.part({
		Name = "RainCloud",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(Rule.cloudRadius * 2, 8, Rule.cloudRadius * 2),
		Position = Vector3.new(x, ground + Rule.cloudHeight, z),
		Color = Color3.fromRGB(110, 110, 130),
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})
	local drops = Instance.new("ParticleEmitter")
	drops.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	drops.Color = ColorSequence.new(Color3.fromRGB(150, 190, 255))
	drops.Rate = 200
	drops.Lifetime = NumberRange.new(1.5)
	drops.Speed = NumberRange.new(30)
	drops.EmissionDirection = Enum.NormalId.Bottom
	drops.SpreadAngle = Vector2.new(15, 15)
	drops.Size = NumberSequence.new(0.3)
	drops.Parent = cloud
	Effects.sound("rain", Vector3.new(x, ground, z))

	local paid: { [Plants.Plant]: boolean } = {}
	local ends = os.clock() + Rule.rainSeconds
	local centre = Vector3.new(x, ground, z)
	while os.clock() < ends do
		for _, plant in Plants.all() do
			if
				not paid[plant]
				and Util.flatDistance(plant.root.Position, centre) <= Rule.cloudRadius
			then
				paid[plant] = true
				local rings = Growth.rainRings(Rings, plant.level)
				Plants.addRings(plant, rings, "rain")
				Effects.notify(plant.player, `Rain! +{rings} rings.`, "good")
				Data.count(plant.player, "rainCaught")
			end
		end
		task.wait(0.25)
	end
	cloud:Destroy()
	shadow:Destroy()
end

function Rain.start()
	folder = Util.folder("Weather")
	task.spawn(function()
		while true do
			task.wait(Util.roll(Rule.minIntervalSeconds, Rule.maxIntervalSeconds))
			local ok, err = pcall(oneCloud)
			if not ok then
				warn(`[Rain] {err}`)
			end
		end
	end)
end

return Rain
