--[[
	Taking root: at `Levels.rootRings` (80) rings a player can choose to root as a Deciduodocus.
	The tree stands for about 2 minutes, drops fruit every 20 seconds and
	counts on the Treederboard (the Trees column of the player list).

	After rooting, the player watches the tree grow and drop its first fruit
	(their plant is hidden and safe meanwhile). Then they press Respawn, or
	wait `watchSeconds`, and start again as a Seedling with a fruit to eat.
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
local PlantModel = require(script.Parent.PlantModel)
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

-- Grows a new tree from tiny to full size, then drops its first fruit.
-- Keeps the trunk standing on the ground (scaling keeps the trunk's centre).
local function standOnGround(tree: Model, ground: Vector3)
	local pivot = tree:GetPivot()
	local trunk = tree.PrimaryPart :: BasePart
	-- The trunk is a cylinder on its side, so its height is Size.X.
	local bottom = pivot.Position.Y - trunk.Size.X / 2
	tree:PivotTo(pivot + Vector3.new(0, ground.Y - bottom, 0))
end

local function growTree(tree: Model, ground: Vector3)
	tree:ScaleTo(Rule.growStartScale)
	standOnGround(tree, ground)
	task.spawn(function()
		for step = 1, Rule.growSteps do
			task.wait(Rule.growSeconds / Rule.growSteps)
			if tree.Parent == nil then
				return
			end
			local share = step / Rule.growSteps
			tree:ScaleTo(Rule.growStartScale + (1 - Rule.growStartScale) * share)
			standOnGround(tree, ground)
		end
		Pickups.dropRandomFruit(ground)
	end)
end

-- Stops watching the tree: the player starts again as a Seedling.
local function finishWatching(plant: Plants.Plant)
	if not plant.watchingTree then
		return
	end
	plant.watchingTree = false
	PlantModel.setHidden(plant.model, false)
	local player = plant.player
	if player then
		player:SetAttribute("WatchTree", nil)
		player:SetAttribute("RespawnReadyAt", nil)
	end
	Plants.respawn(plant, "rooted")
	for _ = 1, Rule.respawnFruit do
		Pickups.dropRandomFruit(plant.root.Position)
	end
end

local function root(player: Player)
	local plant = Plants.forPlayer(player)
	if plant == nil or plant.watchingTree or not Growth.canRoot(plant.rings, Levels.rootRings) then
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

	-- Watch the tree grow: the plant is hidden, held still and safe.
	local now = Plants.now()
	plant.watchingTree = true
	plant.root.Anchored = true
	PlantModel.setHidden(plant.model, true)
	player:SetAttribute("WatchTree", ground + Vector3.new(0, Rule.trunkHeight / 2, 0))
	player:SetAttribute("RespawnReadyAt", now + Rule.growSeconds)
	Plants.sync(plant)
	growTree(tree, ground)
	task.delay(Rule.watchSeconds, function()
		finishWatching(plant)
	end)

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
	Remotes.event("Respawn").OnServerEvent:Connect(function(player)
		local plant = Plants.forPlayer(player)
		local ready = player:GetAttribute("RespawnReadyAt")
		if plant and type(ready) == "number" and Plants.now() >= ready then
			finishWatching(plant)
		end
	end)
end

return Rooting
