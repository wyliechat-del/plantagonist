--[[
	Map features that each client runs for itself:
	- Swimming is off, so plants wade through the shallow river.
	- Lily pads: landing on one springs your plant into a frog hop you can
	  steer (your own client moves your character).
	- The rope bridge swings like a cradle from a line high above it, most
	  in the middle (looks only).
	- The hiding grass blades wave a little (looks only).
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
			Vector3.new(move.X, MapRules.hopLaunchSpeed(workspace.Gravity, pads.hopHeight), move.Z)
	end
end

-- Rope bridge sway -------------------------------------------------------

local swayParts: { { part: BasePart, base: CFrame, share: number } } = {}
local swayPivot: CFrame? = nil
local swayDegrees, swaySeconds = 0, 1

-- Finds the rope bridge's swinging parts. Run again every second: with
-- streaming, or while the map is still arriving, the parts turn up a few at
-- a time. Each part's resting place comes from its `SwayBase` attribute,
-- so finding it again mid swing is safe.
local function findRopeBridge()
	local map = workspace:FindFirstChild("Map")
	local river = map and map:FindFirstChild("River")
	local bridge = river and river:FindFirstChild("RopeBridge")
	if bridge == nil then
		swayPivot = nil
		swayParts = {}
		return
	end
	local pivot = bridge:GetAttribute("SwayPivot")
	if typeof(pivot) ~= "CFrame" then
		return
	end
	swayDegrees = bridge:GetAttribute("SwayDegrees") or 0
	swaySeconds = bridge:GetAttribute("SwaySeconds") or 1
	local parts = {}
	for _, part in bridge:GetDescendants() do
		local base = part:GetAttribute("SwayBase")
		if part:IsA("BasePart") and typeof(base) == "CFrame" then
			-- How far along the bridge from its middle the part is.
			local offset = (base.Position - pivot.Position):Dot(pivot.LookVector)
			table.insert(parts, {
				part = part,
				base = base,
				share = MapRules.ropeBridgeSwayShare(Map, offset),
			})
		end
	end
	swayParts = parts
	swayPivot = pivot
end

local function stepSway(now: number)
	if swayPivot == nil or #swayParts == 0 then
		return
	end
	local pivot = swayPivot :: CFrame
	-- Swing like a cradle about a line along the bridge high above it; each
	-- piece swings by its share, most in the middle, none at the posts.
	local rate = math.pi * 2 / swaySeconds
	local amplitude = math.rad(swayDegrees)
	local angle = amplitude * math.sin(now * rate)
	local turnRate = amplitude * rate * math.cos(now * rate)
	for _, entry in swayParts do
		local part = entry.part
		if part.Parent == nil then
			-- Streamed out or rebuilt; the next search tidies the list.
			continue
		end
		local swing = pivot * CFrame.Angles(0, 0, angle * entry.share) * pivot:Inverse()
		local spin = pivot.ZVector * turnRate * entry.share
		part.CFrame = swing * entry.base
		-- Give the anchored parts the speed they move at, so a plant standing
		-- on the deck rides along smoothly instead of being jolted each frame.
		part.AssemblyLinearVelocity = spin:Cross(part.Position - pivot.Position)
		part.AssemblyAngularVelocity = spin
	end
end

-- Grass waving -----------------------------------------------------------

type Blade = { base: CFrame, pieces: { BasePart }, offsets: { CFrame } }
local blades: { Blade } = {}
local grassModel: Instance? = nil

local function findGrass()
	local map = workspace:FindFirstChild("Map")
	if map == nil then
		return
	end
	-- Each quarter's hiding grass blades are in a model named HidingGrass.
	local models = {}
	for _, folder in map:GetChildren() do
		for _, child in folder:GetChildren() do
			if child.Name == "HidingGrass" and child:IsA("Model") then
				table.insert(models, child)
			end
		end
	end
	local model = models[1]
	if model == nil then
		return
	end
	-- Vector3 is a value type, so blades sharing a base match by position.
	local byBase: { [Vector3]: Blade } = {}
	blades = {}
	local pieces = {}
	for _, each in models do
		for _, piece in each:GetChildren() do
			table.insert(pieces, piece)
		end
	end
	for _, piece in pieces do
		local base = piece:GetAttribute("BladeBase")
		if piece:IsA("BasePart") and typeof(base) == "CFrame" then
			local blade = byBase[base.Position]
			if blade == nil then
				blade = { base = base, pieces = {}, offsets = {} }
				byBase[base.Position] = blade
				table.insert(blades, blade)
			end
			table.insert(blade.pieces, piece)
			table.insert(blade.offsets, base:ToObjectSpace(piece.CFrame))
		end
	end
	grassModel = model
end

local function stepWave(now: number)
	if grassModel == nil or grassModel.Parent == nil then
		grassModel = nil
		return
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local grass = Map.HidingGrass
	local eye = camera.CFrame.Position
	local parts, frames = {}, {}
	for _, blade in blades do
		local base = blade.base
		if (base.Position - eye).Magnitude <= grass.waveDistance then
			local lean = MapRules.grassWave(Map, now, base.Position.X, base.Position.Z)
			-- Lean about the world X axis at the blade's foot, like wind.
			local moved = CFrame.Angles(lean, 0, 0) * base.Rotation + base.Position
			for index, piece in blade.pieces do
				table.insert(parts, piece)
				table.insert(frames, moved * blade.offsets[index])
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
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

	-- Find the rope bridge and the grass once the map is built (and again
	-- if it's rebuilt).
	task.spawn(function()
		while true do
			findRopeBridge()
			if grassModel == nil then
				findGrass()
			end
			task.wait(1)
		end
	end)

	local grassTimer = 0
	-- The bridge moves before each physics step, so plants on it move with it.
	RunService.PreSimulation:Connect(function()
		-- Server time, so every player sees the bridge in the same place.
		stepSway(workspace:GetServerTimeNow())
	end)

	local waveTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		stepHop(now)
		waveTimer += dt
		if waveTimer >= 1 / Map.HidingGrass.waveRate then
			waveTimer = 0
			stepWave(now)
		end
		grassTimer += dt
		if grassTimer >= Map.HidingGrass.checkSeconds then
			grassTimer = 0
			stepGrass()
		end
	end)
end

return World
