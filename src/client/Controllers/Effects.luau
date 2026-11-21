--[[
	Effects the server asks for: sounds, the root flash, pushes (being tossed
	or bouncing as a blowfish) and bat flight. Pushes and flight run here
	because each player's own client moves their character.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

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

local function fly(seconds: number, lift: number)
	local part = root()
	if part == nil then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "FlyAttachment"
	attachment.Parent = part
	local force = Instance.new("VectorForce")
	force.Name = "BatWings"
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.new(0, part.AssemblyMass * workspace.Gravity, 0)
	force.Parent = part
	part.AssemblyLinearVelocity += Vector3.new(0, lift, 0)
	task.delay(seconds, function()
		force:Destroy()
		attachment:Destroy()
	end)
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
		elseif kind == "fly" and type(info.seconds) == "number" then
			fly(info.seconds, if type(info.lift) == "number" then info.lift else 20)
		end
	end)
end

return Effects
