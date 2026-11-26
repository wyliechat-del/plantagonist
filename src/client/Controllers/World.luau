--[[
	Map features that each client runs for itself:
	- Swimming is off, so plants wade through the shallow river.
	- Lily pads: landing on one springs your plant into a frog hop you can
	  steer (your own client moves your character).
	- The rope bridge sways (looks only).
	- Plants hiding in grass (server sets `InGrass` on their model) vanish
	  for everyone else; their name tag stays. Your own looks see-through.
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
			Vector3.new(move.X, MapRules.hopLaunchSpeed(workspace.Gravity, pads.hopSeconds), move.Z)
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
	local angle = math.rad(swayDegrees) * math.sin(now * math.pi * 2 / swaySeconds)
	-- Roll about the bridge's length.
	local roll = pivot * CFrame.Angles(0, 0, angle) * pivot:Inverse()
	for _, entry in swayParts do
		entry.part.CFrame = roll * entry.base
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

	local grassTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		stepHop(now)
		stepSway(now)
		grassTimer += dt
		if grassTimer >= Map.HidingGrass.checkSeconds then
			grassTimer = 0
			stepGrass()
		end
	end)
end

return World
