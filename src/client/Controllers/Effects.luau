--[[
	Effects the server asks for: sounds, the root flash, pushes (being tossed
	or bouncing as a blowfish), bat flight and the miss puff. Pushes and flight run here
	because each player's own client moves their character.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local ControlsConfig = require(ReplicatedStorage.Shared.Config.Controls)
local Levels = require(ReplicatedStorage.Shared.Config.Levels)
local PlantsConfig = require(ReplicatedStorage.Shared.Config.Plants)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Hud = require(script.Parent.Hud)

local Effects = {}

local player = Players.LocalPlayer
local HEARING_DISTANCE = 120

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function playSound(name: string, position: Vector3?)
	local id = Sounds.ids[name]
	if id == nil then
		return
	end
	local volume = Sounds.volume
	if position then
		local camera = workspace.CurrentCamera
		local distance = if camera then (camera.CFrame.Position - position).Magnitude else 0
		if distance > HEARING_DISTANCE then
			return
		end
		volume *= 1 - distance / HEARING_DISTANCE * 0.7
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = Sounds.pitchMin + math.random() * (Sounds.pitchMax - Sounds.pitchMin)
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function push(velocity: Vector3)
	local part = root()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if part == nil or humanoid == nil then
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	part.AssemblyLinearVelocity = velocity
	task.delay(0.8, function()
		if humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- Bat flight: rise above the tallest plants, zoom around at speed for
-- `seconds`, then glide down. A LinearVelocity sets the whole velocity, so
-- gravity doesn't drag the plant down and the move keys steer it.
local flightToken: {}? = nil

local function fly(seconds: number)
	local part = root()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if part == nil or humanoid == nil then
		return
	end
	local token = {}
	flightToken = token
	local old = part:FindFirstChild("BatWings")
	if old then
		old:Destroy()
	end
	local attachment = part:FindFirstChild("FlyAttachment") or Instance.new("Attachment")
	attachment.Name = "FlyAttachment"
	attachment.Parent = part
	local wings = Instance.new("LinearVelocity")
	wings.Name = "BatWings"
	wings.Attachment0 = attachment :: Attachment
	wings.RelativeTo = Enum.ActuatorRelativeTo.World
	wings.MaxForce = math.huge
	wings.VectorVelocity = Vector3.zero
	wings.Parent = part
	player:SetAttribute("FlyingLocal", true)
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

	local speed = Levels.list[1].speed * Levels.studsPerSpeedUnit * PlantsConfig.flySpeedMultiplier
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance }
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - started
		local gliding = elapsed >= seconds
		local done = flightToken ~= token
			or part.Parent == nil
			or elapsed >= seconds + PlantsConfig.flyGlideMaxSeconds
		local below = workspace:Raycast(part.Position, Vector3.new(0, -500, 0), params)
		local height = if below then part.Position.Y - below.Position.Y else math.huge
		if gliding and height < humanoid.HipHeight + part.Size.Y + PlantsConfig.flyLandingStuds then
			done = true
		end
		if done then
			connection:Disconnect()
			wings:Destroy()
			if flightToken == token then
				flightToken = nil
				player:SetAttribute("FlyingLocal", false)
			end
			return
		end
		local move = humanoid.MoveDirection * speed
		local vertical
		if gliding then
			vertical = -PlantsConfig.flyGlideSpeed
		else
			local gap = PlantsConfig.flyHeight - height
			vertical = math.clamp(
				gap * PlantsConfig.flyHeightGain,
				-PlantsConfig.flyLiftSpeed,
				PlantsConfig.flyLiftSpeed
			)
		end
		wings.VectorVelocity = Vector3.new(move.X, vertical, move.Z)
	end)
end

-- A snap at the air: a white puff that grows and fades where the bite missed.
local function missPuff(position: Vector3, scale: number)
	local size = ControlsConfig.missSize * scale
	local puff = Instance.new("Part")
	puff.Name = "MissPuff"
	puff.Shape = Enum.PartType.Ball
	puff.Anchored = true
	puff.CanCollide = false
	puff.CanQuery = false
	puff.CanTouch = false
	puff.Material = Enum.Material.Neon
	puff.Color = Color3.new(1, 1, 1)
	puff.Transparency = 0.3
	puff.Size = Vector3.one * size * 0.4
	puff.Position = position
	puff.Parent = workspace
	local tween = TweenService:Create(
		puff,
		TweenInfo.new(ControlsConfig.missSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * size, Transparency = 1 }
	)
	tween.Completed:Connect(function()
		puff:Destroy()
	end)
	tween:Play()
end

-- A big plant roars before it bites: its head flashes red and swells a
-- little for the roar, then goes back.
local function roar(model: Instance, seconds: number)
	local visual = model:FindFirstChild("PlantVisual")
	local head = visual and visual:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local colour = head.Color
	local info =
		TweenInfo.new(seconds / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	local tween = TweenService:Create(head, info, { Color = Color3.fromRGB(255, 40, 40) })
	tween.Completed:Connect(function()
		head.Color = colour
	end)
	tween:Play()
end

function Effects.start()
	Remotes.event("Effect").OnClientEvent:Connect(function(kind, data)
		local info = if type(data) == "table" then data else {}
		if kind == "sound" and type(info.name) == "string" then
			playSound(info.name, if typeof(info.position) == "Vector3" then info.position else nil)
		elseif kind == "flash" then
			Hud.flash()
		elseif kind == "push" and typeof(info.velocity) == "Vector3" then
			push(info.velocity)
		elseif kind == "roar" and typeof(info.model) == "Instance" then
			roar(info.model, if type(info.seconds) == "number" then info.seconds else 0.25)
		elseif kind == "miss" and typeof(info.position) == "Vector3" then
			missPuff(info.position, if type(info.scale) == "number" then info.scale else 1)
		elseif kind == "fly" and type(info.seconds) == "number" then
			fly(info.seconds)
		end
	end)
end

return Effects
