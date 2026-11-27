--[[
	Map features that each client runs for itself:
	- Swimming is off, so plants wade through the shallow river.
	- Lily pads: landing on one springs your plant into a frog hop you can
	  steer (your own client moves your character).
	- The rope bridge swings like a cradle from its post tops (looks only).
	- Plants hiding in grass (server sets `InGrass` on their model) vanish
	  for everyone else; their name tag stays. Your own looks see-through.
	- Bats fly out of the Hills cave and back (looks only).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local MapRules = require(ReplicatedStorage.Shared.Rules.Map)

local World = {}

local player = Players.LocalPlayer
local pads = Map.LilyPads

-- Frog hop ---------------------------------------------------------------

local hopUntil = 0
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude

local function onLilyPad(character: Model, root: BasePart, humanoid: Humanoid): boolean
	if humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end
	floorParams.FilterDescendantsInstances = { character }
	local reach = humanoid.HipHeight + root.Size.Y / 2 + 1
	local result = workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), floorParams)
	return result ~= nil and result.Instance:GetAttribute("LilyPad") == true
end

local function stepHop(now: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if character == nil or humanoid == nil or root == nil or humanoid.Health <= 0 then
		return
	end
	-- Bat flight steers the plant itself; strangled plants (speed 0) stay put.
	if player:GetAttribute("FlyingLocal") == true or humanoid.WalkSpeed <= 0 then
		hopUntil = 0
		return
	end
	if now < hopUntil then
		-- Steer in the air like flying.
		local move = humanoid.MoveDirection * pads.hopSpeed
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(move.X, velocity.Y, move.Z)
		return
	end
	if onLilyPad(character, root, humanoid) then
		-- No wait between pads: every landing springs again.
		hopUntil = now + pads.hopSeconds
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		local move = humanoid.MoveDirection * pads.hopSpeed
		root.AssemblyLinearVelocity =
			Vector3.new(move.X, MapRules.hopLaunchSpeed(workspace.Gravity, pads.hopHeight), move.Z)
	end
end

-- Rope bridge sway -------------------------------------------------------

local swayParts: { { part: BasePart, base: CFrame } } = {}
local swayPivot: CFrame? = nil
local swayDegrees, swaySeconds = 0, 1

local function findRopeBridge()
	local map = workspace:FindFirstChild("Map")
	local river = map and map:FindFirstChild("River")
	local bridge = river and river:FindFirstChild("RopeBridge")
	if bridge == nil then
		return
	end
	local pivot = bridge:GetAttribute("SwayPivot")
	if typeof(pivot) ~= "CFrame" then
		return
	end
	swayPivot = pivot
	swayDegrees = bridge:GetAttribute("SwayDegrees") or 0
	swaySeconds = bridge:GetAttribute("SwaySeconds") or 1
	swayParts = {}
	for _, part in bridge:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Sway") == true then
			table.insert(swayParts, { part = part, base = part.CFrame })
		end
	end
end

local function stepSway(now: number)
	if swayPivot == nil or #swayParts == 0 then
		return
	end
	if swayParts[1].part.Parent == nil then
		-- The map was rebuilt.
		swayPivot = nil
		return
	end
	local pivot = swayPivot :: CFrame
	-- Swing like a cradle about a line along the bridge at the post tops.
	local rate = math.pi * 2 / swaySeconds
	local amplitude = math.rad(swayDegrees)
	local angle = amplitude * math.sin(now * rate)
	local spin = pivot.ZVector * amplitude * rate * math.cos(now * rate)
	local swing = pivot * CFrame.Angles(0, 0, angle) * pivot:Inverse()
	for _, entry in swayParts do
		local part = entry.part
		part.CFrame = swing * entry.base
		-- Give the anchored parts the speed they move at, so a plant standing
		-- on the deck rides along smoothly instead of being jolted each frame.
		part.AssemblyLinearVelocity = spin:Cross(part.Position - pivot.Position)
		part.AssemblyAngularVelocity = spin
	end
end

-- Hiding grass ------------------------------------------------------------

local hiddenModels: { [Model]: number } = {}

local function setModelTransparency(model: Model, amount: number)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.LocalTransparencyModifier = amount
		end
	end
end

local function plantModels(): { Model }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	local npcs = workspace:FindFirstChild("NPCs")
	for _, model in if npcs then npcs:GetChildren() else {} do
		if model:IsA("Model") then
			table.insert(list, model)
		end
	end
	return list
end

local function stepGrass()
	local seen = {}
	for _, model in plantModels() do
		seen[model] = true
		local hidden = model:GetAttribute("InGrass") == true
		local amount = if not hidden
			then 0
			elseif model == player.Character then Map.HidingGrass.ownTransparency
			else 1
		if (hiddenModels[model] or 0) ~= amount then
			hiddenModels[model] = if amount > 0 then amount else nil
			setModelTransparency(model, amount)
		end
	end
	for model in hiddenModels do
		if not seen[model] then
			hiddenModels[model] = nil
		end
	end
end

-- Cave bats -------------------------------------------------------------

type Bat = { body: BasePart, left: BasePart, right: BasePart, offset: number, side: number }
local bats: { Bat } = {}

local function makeBats()
	local config = Map.Hills.caveBats
	local folder = Instance.new("Folder")
	folder.Name = "CaveBats"
	folder.Parent = workspace
	local colour = Color3.fromRGB(config.colour[1], config.colour[2], config.colour[3])
	local function piece(name: string, size: Vector3, shape: Enum.PartType): BasePart
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape
		part.Size = size
		part.Color = colour
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = folder
		return part
	end
	local length = MapRules.loopLength(config.route)
	for index = 1, config.count do
		local half = config.wingSpan / 2
		table.insert(bats, {
			body = piece("Bat", Vector3.new(0.8, 0.8, 0.8), Enum.PartType.Ball),
			left = piece("Wing", Vector3.new(half, 0.1, 0.8), Enum.PartType.Block),
			right = piece("Wing", Vector3.new(half, 0.1, 0.8), Enum.PartType.Block),
			-- Spread along the loop, in a loose stream.
			offset = (index - 1) / config.count * length,
			side = index * 1.7,
		})
	end
end

local function stepBats(now: number)
	local config = Map.Hills.caveBats
	local half = config.wingSpan / 2
	for _, bat in bats do
		local x, y, z, dx, dy, dz =
			MapRules.alongLoop(config.route, now * config.speed + bat.offset)
		local ahead = Vector3.new(dx, dy, dz)
		-- Weave a little side to side and up and down.
		local across = Vector3.new(-dz, 0, dx)
		local position = Vector3.new(x, y, z)
			+ across * math.sin(now * 1.3 + bat.side) * config.wobble
			+ Vector3.yAxis * math.sin(now * 1.9 + bat.side * 2) * config.wobble * 0.6
		local frame = CFrame.lookAt(position, position + ahead)
		local flap = math.sin(now * config.flapsPerSecond * math.pi * 2 + bat.side) * math.rad(35)
		bat.body.CFrame = frame
		bat.left.CFrame = frame * CFrame.Angles(0, 0, flap) * CFrame.new(-half / 2 - 0.3, 0, 0)
		bat.right.CFrame = frame * CFrame.Angles(0, 0, -flap) * CFrame.new(half / 2 + 0.3, 0, 0)
	end
end

-- Setup -------------------------------------------------------------------

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	end
	hopUntil = 0
end

function World.start()
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	-- Find the rope bridge once the map is built (and again if it's rebuilt).
	task.spawn(function()
		while true do
			if swayPivot == nil then
				findRopeBridge()
			end
			task.wait(1)
		end
	end)

	makeBats()

	local grassTimer = 0
	-- The bridge moves before each physics step, so plants on it move with it.
	RunService.PreSimulation:Connect(function()
		stepSway(os.clock())
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		stepHop(now)
		stepBats(now)
		grassTimer += dt
		if grassTimer >= Map.HidingGrass.checkSeconds then
			grassTimer = 0
			stepGrass()
		end
	end)
end

return World
