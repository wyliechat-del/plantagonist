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

-- A ring of glowing pieces at `radius` around (x, z).
local function ringFrames(
	x: number,
	z: number,
	y: number,
	radius: number,
	count: number
): { CFrame }
	local frames = {}
	for index = 1, count do
		local angle = (index / count) * math.pi * 2
		local position = Vector3.new(x + math.cos(angle) * radius, y, z + math.sin(angle) * radius)
		table.insert(frames, CFrame.lookAt(position, Vector3.new(x, y, z)))
	end
	return frames
end

-- Rings that sweep in from across the territory to the rain spot.
local function sweepRings(x: number, z: number, ground: number)
	local rings = {}
	for ring = 1, Rule.ringCount do
		local parts = {}
		for _ = 1, Rule.ringSegments do
			table.insert(
				parts,
				Util.part({
					Name = "RainRing",
					Size = Vector3.new(4, 0.6, 1),
					Color = Color3.fromRGB(120, 180, 255),
					Material = Enum.Material.Neon,
					Transparency = 1,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					Parent = folder,
				})
			)
		end
		rings[ring] = parts
	end
	local started = os.clock()
	while os.clock() - started < Rule.shadowSeconds do
		local elapsed = os.clock() - started
		local allParts, allFrames = {}, {}
		for ring, parts in rings do
			-- Each ring starts a little after the last and loops.
			local offset = (ring - 1) * Rule.ringSeconds / Rule.ringCount
			local share = ((elapsed + offset) % Rule.ringSeconds) / Rule.ringSeconds
			local radius = Rule.ringStartRadius + (Rule.cloudRadius - Rule.ringStartRadius) * share
			local frames = ringFrames(x, z, ground + 1, radius, #parts)
			for index, part in parts do
				part.Transparency = 0.2 + share * 0.5
				table.insert(allParts, part)
				table.insert(allFrames, frames[index])
			end
		end
		workspace:BulkMoveTo(allParts, allFrames, Enum.BulkMoveMode.FireCFrameChanged)
		task.wait(1 / 15)
	end
	for _, parts in rings do
		for _, part in parts do
			part:Destroy()
		end
	end
end

local function lightning(x: number, z: number, ground: number)
	local top = ground + Rule.cloudHeight
	local bolt = Util.part({
		Name = "Lightning",
		Size = Vector3.new(0.8, Rule.cloudHeight, 0.8),
		Position = Vector3.new(x + (Util.random() - 0.5) * Rule.cloudRadius, (top + ground) / 2, z),
		Color = Color3.fromRGB(255, 255, 200),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})
	Effects.sound("thunder", Vector3.new(x, ground, z))
	task.delay(0.15, function()
		bolt:Destroy()
	end)
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
	Effects.notifyAll(`Rain is coming to the {territory}! Follow the rings.`, "event")

	local shadow = disc(
		"RainShadow",
		Rule.shadowStartRadius,
		ground + 0.4,
		x,
		z,
		Color3.fromRGB(10, 10, 30),
		Rule.shadowTransparency
	)
	local small = Vector3.new(0.3, Rule.cloudRadius * 2, Rule.cloudRadius * 2)
	TweenService
		:Create(
			shadow,
			TweenInfo.new(Rule.shadowSeconds, Enum.EasingStyle.Linear),
			{ Size = small }
		)
		:Play()

	-- The cloud is there from the start, high up, so it can be seen from afar.
	local cloud = Util.part({
		Name = "RainCloud",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(Rule.cloudRadius * 2, 8, Rule.cloudRadius * 2),
		Position = Vector3.new(x, ground + Rule.cloudHeight, z),
		Color = Color3.fromRGB(80, 80, 100),
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})
	task.delay(math.max(Rule.shadowSeconds - Rule.lightningSeconds, 0), function()
		for _ = 1, Rule.lightningFlashes do
			if cloud.Parent == nil then
				return
			end
			lightning(x, z, ground)
			task.wait(Rule.lightningSeconds / Rule.lightningFlashes)
		end
	end)
	sweepRings(x, z, ground)

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
