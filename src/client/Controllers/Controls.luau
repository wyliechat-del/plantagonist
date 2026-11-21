--[[
	Touch-friendly controls: a big bite button, up to 3 attack slot buttons
	(family colours, named by attack type: a triangle for ranged, a square
	button for melee, a dot when a boost is loaded), defence slot badges and a Take Root button. Movement
	uses Roblox's own thumbstick on phones and WASD on desktop. Keys: E bites,
	1 to 3 use slots, R takes root.

	Aim assist picks the target nearest the crosshair that is in reach and
	outlines it. The server checks every bite again.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local ControlsConfig = require(ReplicatedStorage.Shared.Config.Controls)
local Levels = require(ReplicatedStorage.Shared.Config.Levels)
local PlantsConfig = require(ReplicatedStorage.Shared.Config.Plants)
local PowerUpsConfig = require(ReplicatedStorage.Shared.Config.PowerUps)
local Aim = require(ReplicatedStorage.Shared.Rules.Aim)
local PowerUps = require(ReplicatedStorage.Shared.Rules.PowerUps)
local Bite = require(ReplicatedStorage.Shared.Rules.Bite)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Hud = require(script.Parent.Hud)
local Ui = require(script.Parent.Ui)

local Controls = {}

local player = Players.LocalPlayer
local highlight: Highlight
local attackButtons: { TextButton } = {}
local boostDots: { Frame } = {}
local defenceBadges: { TextLabel } = {}
local rootButton: TextButton
local currentTarget: Instance? = nil

local EMPTY_COLOUR = Color3.fromRGB(90, 90, 90)

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function myLevel(): number
	local level = player:GetAttribute("Level")
	return if type(level) == "number" then level else 1
end

local function plantRadius(level: number): number
	return PlantsConfig.radiusAtScale1 * PlantsConfig.scaleByLevel[level]
end

-- Everything that could be aimed at. `plantsOnly` skips creatures.
local function candidates(plantsOnly: boolean): { Aim.Candidate }
	local list = {}
	if not plantsOnly then
		local folder = workspace:FindFirstChild("Creatures")
		for _, part in if folder then folder:GetChildren() else {} do
			if part:IsA("BasePart") and part:GetAttribute("CreatureId") then
				local p = part.Position
				table.insert(
					list,
					{ key = part, x = p.X, y = p.Y, z = p.Z, radius = part.Size.X / 2 }
				)
			end
		end
	end
	local models = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			table.insert(models, other.Character)
		end
	end
	local npcs = workspace:FindFirstChild("NPCs")
	for _, model in if npcs then npcs:GetChildren() else {} do
		table.insert(models, model)
	end
	for _, model in models do
		local level = model:GetAttribute("PlantLevel")
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hidden = model:GetAttribute("Invisible") == true
			or model:GetAttribute("Protected") == true
		if type(level) == "number" and root and not hidden then
			local p = root.Position
			table.insert(
				list,
				{ key = model, x = p.X, y = p.Y, z = p.Z, radius = plantRadius(level) }
			)
		end
	end
	return list
end

local function pickTarget(plantsOnly: boolean, reach: number): Instance?
	local root = myRoot()
	local camera = workspace.CurrentCamera
	if root == nil or camera == nil then
		return nil
	end
	local c, look, me = camera.CFrame.Position, camera.CFrame.LookVector, root.Position
	local best = Aim.pick(
		candidates(plantsOnly),
		{ x = c.X, y = c.Y, z = c.Z },
		{ x = look.X, y = look.Y, z = look.Z },
		{ x = me.X, y = me.Y, z = me.Z },
		reach + plantRadius(myLevel()),
		ControlsConfig.aimAssistDegrees
	)
	return if best then best.key else nil
end

local function biteReach(): number
	return Bite.reachStuds(CombatConfig, myLevel())
end

local function bite()
	Remotes.event("Bite"):FireServer(currentTarget)
end

local function useSlot(index: number)
	local id = player:GetAttribute(`Attack{index}`)
	if type(id) ~= "string" or id == "" then
		return
	end
	local creature = PowerUpsConfig.creatures[id]
	local target = nil
	if creature and creature.kind == "melee" then
		target = pickTarget(true, biteReach())
	elseif creature and creature.kind == "range" then
		target = pickTarget(true, Bite.rangeStuds(CombatConfig, myLevel()))
	end
	Remotes.event("UseSlot"):FireServer(index, target)
end

local function roundButton(
	name: string,
	size: number,
	position: UDim2,
	colour: Color3,
	text: string
): TextButton
	return Ui.make("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = colour,
		Text = text,
		TextScaled = true,
		TextWrapped = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		AutoButtonColor = true,
		Parent = Hud.gui(),
	}, { Ui.corner(), Ui.stroke(Color3.new(0, 0, 0), 2) })
end

local function refreshSlots()
	local now = workspace:GetServerTimeNow()
	local attackSlots = player:GetAttribute("AttackSlots") or 1
	local defenceSlots = player:GetAttribute("DefenceSlots") or 0
	local lockedUntil = player:GetAttribute("LockoutUntil")
	local locked = type(lockedUntil) == "number" and now < lockedUntil
	for index, button in attackButtons do
		button.Visible = index <= attackSlots
		local id = player:GetAttribute(`Attack{index}`)
		local creature = if type(id) == "string" then PowerUpsConfig.creatures[id] else nil
		local readyAt = player:GetAttribute(`Attack{index}ReadyAt`)
		local waiting = type(readyAt) == "number" and now < readyAt
		local corner = button:FindFirstChildOfClass("UICorner")
		local square = creature ~= nil and creature.kind == "melee"
		if corner then
			corner.CornerRadius =
				UDim.new(if square then ControlsConfig.squareCornerScale else 0.5, 0)
		end
		if creature then
			local mark = ControlsConfig.kindMarks[creature.kind]
			local label = PowerUps.buttonLabel(PowerUpsConfig, id :: string)
			button.BackgroundColor3 = Ui.colour(PowerUpsConfig.families[creature.family].colour)
			button.Text = if locked then "Venom!" elseif mark then `{mark}\n{label}` else label
			button.BackgroundTransparency = if locked or waiting then 0.6 else 0
		else
			button.BackgroundColor3 = EMPTY_COLOUR
			button.Text = "Empty"
			button.BackgroundTransparency = 0.4
		end
		local boost = player:GetAttribute(`Attack{index}Boost`)
		local boosted = creature ~= nil and type(boost) == "string" and boost ~= ""
		local dot = boostDots[index]
		dot.Visible = boosted
		if boosted then
			local boostCreature = PowerUpsConfig.creatures[boost :: string]
			if boostCreature then
				dot.BackgroundColor3 =
					Ui.colour(PowerUpsConfig.families[boostCreature.family].colour)
			end
		end
	end
	for index, badge in defenceBadges do
		badge.Visible = index <= defenceSlots
		local id = player:GetAttribute(`Defence{index}`)
		local creature = if type(id) == "string" then PowerUpsConfig.creatures[id] else nil
		badge.BackgroundColor3 = if creature
			then Ui.colour(PowerUpsConfig.families[creature.family].colour)
			else EMPTY_COLOUR
		badge.Text = if creature
			then `Shield: {PowerUpsConfig.families[creature.family].name}`
			else "Shield: empty"
	end
	local rings = player:GetAttribute("Rings") or 0
	rootButton.Visible = rings >= Levels.rootRings
end

local function buildButtons()
	local size = ControlsConfig.biteButtonSize
	local slotSize = ControlsConfig.slotButtonSize
	local gap = ControlsConfig.buttonGap
	-- Left of Roblox's own jump button, which sits in the bottom right corner on phones.
	local biteCentre = UDim2.new(1, -(size / 2 + 140), 1, -(size / 2 + 30))
	local biteButton = roundButton("Bite", size, biteCentre, Color3.fromRGB(200, 60, 80), "BITE")
	biteButton.Activated:Connect(bite)

	-- Attack slots in an arc above and to the left of the bite button.
	local radius = size / 2 + gap + slotSize / 2
	for index = 1, 3 do
		local angle = math.rad(90 + (index - 1) * 45)
		local offset = UDim2.fromOffset(
			-math.sin(angle - math.rad(90)) * radius,
			-math.cos(angle - math.rad(90)) * radius
		)
		local button =
			roundButton(`Slot{index}`, slotSize, biteCentre + offset, EMPTY_COLOUR, "Empty")
		button.Activated:Connect(function()
			useSlot(index)
		end)
		attackButtons[index] = button
		local dotSize = ControlsConfig.boostDotSize
		boostDots[index] = Ui.make("Frame", {
			Name = "BoostDot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -dotSize / 4, 0, dotSize / 4),
			Size = UDim2.fromOffset(dotSize, dotSize),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Visible = false,
			ZIndex = 2,
			Parent = button,
		}, { Ui.corner(), Ui.stroke(Color3.new(1, 1, 1), 2) })
	end

	for index = 1, 2 do
		defenceBadges[index] = Ui.make("TextLabel", {
			Name = `Defence{index}`,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -(size + 80 + (index - 1) * 30 + radius)),
			Size = UDim2.fromOffset(150, 26),
			BackgroundColor3 = EMPTY_COLOUR,
			Text = "",
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.new(1, 1, 1),
			Visible = false,
			Parent = Hud.gui(),
		}, { Ui.corner(UDim.new(0, 8)) })
	end

	rootButton = Ui.make("TextButton", {
		Name = "TakeRoot",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(200, 54),
		BackgroundColor3 = Color3.fromRGB(230, 160, 40),
		Text = "TAKE ROOT",
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = Hud.gui(),
	}, { Ui.corner(UDim.new(0, 14)), Ui.stroke(Color3.new(0, 0, 0), 2) })
	rootButton.Activated:Connect(function()
		Remotes.event("Root"):FireServer()
	end)
end

function Controls.start()
	buildButtons()
	highlight = Ui.make("Highlight", {
		Name = "AimTarget",
		FillTransparency = 0.7,
		OutlineColor = Color3.fromRGB(255, 255, 120),
		FillColor = Color3.fromRGB(255, 255, 120),
		DepthMode = Enum.HighlightDepthMode.Occluded,
		-- Only this client sees it.
		Parent = workspace,
	})

	for _, name in { "AttackSlots", "DefenceSlots", "Rings", "LockoutUntil" } do
		player:GetAttributeChangedSignal(name):Connect(refreshSlots)
	end
	for index = 1, 3 do
		player:GetAttributeChangedSignal(`Attack{index}`):Connect(refreshSlots)
		player:GetAttributeChangedSignal(`Attack{index}ReadyAt`):Connect(refreshSlots)
		player:GetAttributeChangedSignal(`Attack{index}Boost`):Connect(refreshSlots)
	end
	for index = 1, 2 do
		player:GetAttributeChangedSignal(`Defence{index}`):Connect(refreshSlots)
	end
	refreshSlots()

	local slotKeys = {}
	for index, keyName in ControlsConfig.slotKeys do
		slotKeys[(Enum.KeyCode :: any)[keyName]] = index
	end
	local biteKey = (Enum.KeyCode :: any)[ControlsConfig.biteKey]
	local rootKey = (Enum.KeyCode :: any)[ControlsConfig.rootKey]
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == biteKey then
			bite()
		elseif input.KeyCode == rootKey then
			Remotes.event("Root"):FireServer()
		elseif slotKeys[input.KeyCode] then
			useSlot(slotKeys[input.KeyCode])
		end
	end)

	local lastRefresh = 0
	RunService.RenderStepped:Connect(function()
		currentTarget = pickTarget(false, biteReach())
		highlight.Adornee = currentTarget
		-- Timers (venom, mantis) run out without an attribute change.
		local now = os.clock()
		if now - lastRefresh > 0.25 then
			lastRefresh = now
			refreshSlots()
		end
	end)
end

return Controls
