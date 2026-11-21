--[[
	Taking root: at 94 rings a player can choose to root as a Deciduodocus.
	The tree stands for about 2 minutes, drops fruit every 20 seconds and
	counts on the Treederboard (the Trees column of the player list). The
	player starts again as a Seedling with a fruit to eat.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local Levels = require(ReplicatedStorage.Shared.Config.Levels)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local Growth = require(ReplicatedStorage.Shared.Rules.Growth)
local MapRules = require(ReplicatedStorage.Shared.Rules.Map)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Data = require(script.Parent.Data)
local Effects = require(script.Parent.Effects)
local Log = require(script.Parent.Log)
local MapBuilder = require(script.Parent.MapBuilder)
local Pickups = require(script.Parent.Pickups)
local Plants = require(script.Parent.Plants)
local Util = require(script.Parent.Util)

local Rooting = {}

local Rule = Environment.Rooting
local folder: Folder
local trees: { Model } = {}

local function tooClose(position: Vector3): boolean
	for _, tree in trees do
		if
			tree.Parent
			and Util.flatDistance(tree:GetPivot().Position, position) < Rule.minTreeSpacing
		then
			return true
		end
	end
	return false
end

local function buildTree(position: Vector3, owner: string): Model
	local model = Instance.new("Model")
	model.Name = `{owner}'s {Rule.name}`
	local trunk = Util.part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(Rule.trunkHeight, 6, 6),
		CFrame = CFrame.new(position + Vector3.new(0, Rule.trunkHeight / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 85, 50),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	Util.part({
		Name = "Crown",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * Rule.crownSize,
		Position = position + Vector3.new(0, Rule.trunkHeight, 0),
		Color = Color3.fromRGB(230, 150, 50),
		Material = Enum.Material.Grass,
		CanCollide = false,
		Parent = model,
	})
	model.PrimaryPart = trunk
	model.Parent = folder
	Util.label(trunk, model.Name, Rule.trunkHeight / 2 + Rule.crownSize / 2 + 2)
	local label = trunk:FindFirstChild("Label") :: BillboardGui?
	if label then
		label.MaxDistance = 300
	end
	return model
end

local function root(player: Player)
	local plant = Plants.forPlayer(player)
	if plant == nil or not Growth.canRoot(plant.rings, Levels.rootRings) then
		return
	end
	local position = plant.root.Position
	if MapRules.inField(Map, position.X, position.Z) then
		Effects.notify(player, "You can't take root in the safe field.", "info")
		return
	end
	if tooClose(position) then
		Effects.notify(player, "Too close to another tree. Find some space!", "info")
		return
	end
	local ground = Vector3.new(position.X, MapBuilder.groundY(position.X, position.Z), position.Z)
	local tree = buildTree(ground, plant.name)
	table.insert(trees, tree)

	local stats = player:FindFirstChild("leaderstats")
	local count = stats and stats:FindFirstChild("Trees") :: IntValue?
	if count then
		count.Value += 1
	end
	Data.count(player, "rooted")
	Log.event(player, "Rooted", math.floor(Plants.now() - plant.spawnedAt))
	Effects.notifyAll(`{plant.name} took root as a {Rule.name}!`, "event")
	Effects.sendAll("flash", { position = ground })
	Effects.sound("choir", ground)

	Plants.respawn(plant, "rooted")
	for _ = 1, Rule.respawnFruit do
		Pickups.dropRandomFruit(plant.root.Position)
	end

	task.spawn(function()
		local ends = os.clock() + Rule.treeSeconds
		while os.clock() < ends do
			task.wait(Rule.fruitEverySeconds)
			if tree.Parent == nil then
				return
			end
			for _ = 1, Util.roll(Rule.fruitMin, Rule.fruitMax) do
				Pickups.dropRandomFruit(ground)
			end
		end
		local index = table.find(trees, tree)
		if index then
			table.remove(trees, index)
		end
		tree:Destroy()
	end)
end

function Rooting.start()
	folder = Util.folder("Trees")
	Remotes.event("Root").OnServerEvent:Connect(root)
end

return Rooting
