--[[
	Touch-friendly controls. Bites go where you click (desktop) or tap
	(phone); clicking empty ground snaps at the air. Whatever is in bite reach
	under the mouse is outlined (on phones, the nearest thing in reach).

	Up to 3 attack slot buttons (family colours, named by attack type: a
	triangle for ranged, a square button for melee, a dot when a boost is
	loaded). Tapping a melee or ranged slot (or pressing 1 to 3) primes it for
	the next click; tapping it again cancels. Moves (Fly, Puff, Dash, Hide) go
	off straight away. Defence slot badges and a Take Root button too. After
	rooting, the camera circles the new tree until you press Respawn.

	Movement uses Roblox's own thumbstick on phones and WASD on desktop.
	Keys: E bites where the mouse points, 1 to 3 prime slots, R takes root.
	The server checks every bite again.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local ControlsConfig = require(ReplicatedStorage.Shared.Config.Controls)
local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local Levels = require(ReplicatedStorage.Shared.Config.Levels)
local PlantsConfig = require(ReplicatedStorage.Shared.Config.Plants)
local PowerUpsConfig = require(ReplicatedStorage.Shared.Config.PowerUps)
local Aim = require(ReplicatedStorage.Shared.Rules.Aim)
local Bite = require(ReplicatedStorage.Shared.Rules.Bite)
local PowerUps = require(ReplicatedStorage.Shared.Rules.PowerUps)
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
local respawnButton: TextButton
-- The attack slot that the next click uses, if any.
local primedSlot: number? = nil

local EMPTY_COLOUR = Color3.fromRGB(90, 90, 90)
local HUGE_REACH = math.huge

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

local function point(v: Vector3): Aim.Point
	return { x = v.X, y = v.Y, z = v.Z }
end

-- Everything that could be bitten. `plantsOnly` skips creatures and cows.
local function candidates(plantsOnly: boolean): { Aim.Candidate }
	local list = {}
	if not plantsOnly then
		local folder = workspace:FindFirstChild("Creatures")
		for _, part in if folder then folder:GetChildren() else {} do
			if part:IsA("BasePart") and (part:GetAttribute("CreatureId") or part.Name == "Cow") then
				local p = part.Position
				local radius = math.max(part.Size.X, part.Size.Z) / 2
				table.insert(list, { key = part, x = p.X, y = p.Y, z = p.Z, radius = radius })
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

-- The id and kind of the power up in an attack slot, if it has one.
local function slotPowerUp(index: number): (string?, string?)
	local id = player:GetAttribute(`Attack{index}`)
	if type(id) ~= "string" or id == "" then
		return nil, nil
	end
	local creature = PowerUpsConfig.creatures[id]
	return id, if creature then creature.kind else nil
end

-- Reach from the plant's edge for a bite, or for the primed power up.
local function biteReach(): number
	return Bite.reachStuds(CombatConfig, myLevel()) + plantRadius(myLevel())
end

local function primedKind(): string?
	if primedSlot == nil then
		return nil
	end
	local _, kind = slotPowerUp(primedSlot)
	return kind
end

local function primedReach(): number
	if primedKind() == "range" then
		return Bite.rangeStuds(CombatConfig, myLevel()) + plantRadius(myLevel())
	end
	return biteReach()
end

local function screenRay(position: Vector2, isTouch: boolean): Ray?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	-- Mouse positions include the top bar inset; touch positions don't.
	return if isTouch
		then camera:ScreenPointToRay(position.X, position.Y)
		else camera:ViewportPointToRay(position.X, position.Y)
end

-- What a click at `ray` picks: the target in `reach`, whether something out
-- of reach was clicked, and the world point under the click.
local function pickAt(
	ray: Ray,
	plantsOnly: boolean,
	reach: number,
	slack: number
): (Instance?, boolean, Vector3)
	local root = myRoot()
	local list = candidates(plantsOnly)
	local origin, direction = point(ray.Origin), point(ray.Direction.Unit)
	local from = if root then point(root.Position) else origin
	local inReach = Aim.pickOnRay(list, origin, direction, from, reach, slack)
	local anything = inReach or Aim.pickOnRay(list, origin, direction, from, HUGE_REACH, slack)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction.Unit * 500, params)
	local worldPoint = if hit then hit.Position else ray.Origin + ray.Direction.Unit * 50
	return if inReach then inReach.key else nil, anything ~= nil and inReach == nil, worldPoint
end

local function clearPrimed()
	primedSlot = nil
end

-- A click or tap in the world.
local function clickAt(ray: Ray, isTouch: boolean)
	local slack = if isTouch then ControlsConfig.tapSlackStuds else ControlsConfig.clickSlackStuds
	if player:GetAttribute("FlyingLocal") == true then
		-- Aiming from the air is hard, so clicks near a plant count.
		slack = math.max(slack, PlantsConfig.flyClickSlackStuds)
	end
	local kind = primedKind()
	if primedSlot and (kind == "range" or kind == "melee") then
		local target, _, worldPoint = pickAt(ray, true, primedReach(), slack)
		-- Ranged attacks fire toward the click even if nothing is there.
		if kind == "range" or target then
			Remotes.event("UseSlot"):FireServer(primedSlot, target, worldPoint)
			clearPrimed()
			return
		end
		-- A primed melee attack waits for a plant; this click is a normal bite.
	end
	local target, outOfReach, worldPoint = pickAt(ray, false, biteReach(), slack)
	if target then
		Remotes.event("Bite"):FireServer(target, worldPoint)
	elseif not outOfReach then
		-- Nothing there: snap at the air.
		Remotes.event("Bite"):FireServer(nil, worldPoint)
	end
end

local function pressSlot(index: number)
	local id, kind = slotPowerUp(index)
	if id == nil then
		return
	end
	if kind == "special" then
		Remotes.event("UseSlot"):FireServer(index, nil, nil)
		clearPrimed()
	elseif primedSlot == index then
		clearPrimed()
	else
		primedSlot = index
	end
end

local function slotButton(name: string, size: number, position: UDim2): TextButton
	return Ui.make("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = EMPTY_COLOUR,
		Text = "Empty",
		TextScaled = true,
		TextWrapped = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		AutoButtonColor = true,
		Parent = Hud.gui(),
	}, {
		Ui.corner(),
		Ui.make("UIStroke", {
			Color = Color3.new(0, 0, 0),
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

local function refreshSlots()
	local now = workspace:GetServerTimeNow()
	local attackSlots = player:GetAttribute("AttackSlots") or 1
	local defenceSlots = player:GetAttribute("DefenceSlots") or 0
	local lockedUntil = player:GetAttribute("LockoutUntil")
	local locked = type(lockedUntil) == "number" and now < lockedUntil
	if primedSlot and (slotPowerUp(primedSlot) == nil or primedSlot > attackSlots) then
		clearPrimed()
	end
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
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			local primed = primedSlot == index
			stroke.Color = if primed
				then Ui.colour(ControlsConfig.primedColour)
				else Color3.new(0, 0, 0)
			stroke.Thickness = if primed then ControlsConfig.primedStroke else 2
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
	local watching = typeof(player:GetAttribute("WatchTree")) == "Vector3"
	local readyAt = player:GetAttribute("RespawnReadyAt")
	rootButton.Visible = rings >= Levels.rootRings and not watching
	respawnButton.Visible = watching and type(readyAt) == "number" and now >= readyAt
end

local function buildButtons()
	local slotSize = ControlsConfig.slotButtonSize
	local gap = ControlsConfig.buttonGap

	-- Attack slots in a row, right to left, left of Roblox's jump button.
	for index = 1, 3 do
		local x = ControlsConfig.slotRowRightOffset + slotSize / 2 + (index - 1) * (slotSize + gap)
		local position = UDim2.new(1, -x, 1, -(slotSize / 2 + ControlsConfig.slotRowBottomOffset))
		local button = slotButton(`Slot{index}`, slotSize, position)
		button.Activated:Connect(function()
			pressSlot(index)
			refreshSlots()
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

	local above = slotSize + ControlsConfig.slotRowBottomOffset + gap
	for index = 1, 2 do
		defenceBadges[index] = Ui.make("TextLabel", {
			Name = `Defence{index}`,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -(above + (index - 1) * 30)),
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

	respawnButton = Ui.make("TextButton", {
		Name = "Respawn",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(200, 54),
		BackgroundColor3 = Color3.fromRGB(70, 160, 70),
		Text = "RESPAWN",
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = Hud.gui(),
	}, { Ui.corner(UDim.new(0, 14)), Ui.stroke(Color3.new(0, 0, 0), 2) })
	respawnButton.Activated:Connect(function()
		Remotes.event("Respawn"):FireServer()
	end)
end

-- Outlines what a click would bite: under the mouse on desktop, the nearest
-- thing in reach on phones.
local function updateHighlight()
	local root = myRoot()
	local plantsOnly = primedSlot ~= nil
	local reach = primedReach()
	local target: Instance? = nil
	if root and UserInputService.MouseEnabled then
		local ray = screenRay(UserInputService:GetMouseLocation(), false)
		if ray then
			target = pickAt(ray, plantsOnly, reach, ControlsConfig.clickSlackStuds)
		end
	elseif root then
		local best = Aim.nearest(candidates(plantsOnly), point(root.Position), reach)
		target = if best then best.key else nil
	end
	local colour =
		Ui.colour(if plantsOnly then ControlsConfig.primedColour else ControlsConfig.reachColour)
	highlight.OutlineColor = colour
	highlight.FillColor = colour
	highlight.Adornee = target
end

-- After rooting, the camera circles the new tree until the player respawns.
local function updateTreeCamera(started: number)
	local camera = workspace.CurrentCamera
	local tree = player:GetAttribute("WatchTree")
	if camera == nil then
		return
	end
	if typeof(tree) ~= "Vector3" then
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
			local character = player.Character
			camera.CameraSubject = character and character:FindFirstChildOfClass("Humanoid")
		end
		return
	end
	local rule = Environment.Rooting
	camera.CameraType = Enum.CameraType.Scriptable
	local angle = math.rad((os.clock() - started) * rule.cameraDegreesPerSecond)
	local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rule.cameraDistance
	local eye = tree + offset + Vector3.new(0, rule.cameraHeight, 0)
	camera.CFrame = CFrame.lookAt(eye, tree)
end

function Controls.start()
	buildButtons()
	highlight = Ui.make("Highlight", {
		Name = "AimTarget",
		FillTransparency = 0.7,
		DepthMode = Enum.HighlightDepthMode.Occluded,
		-- Only this client sees it.
		Parent = workspace,
	})

	for _, name in { "AttackSlots", "DefenceSlots", "Rings", "LockoutUntil", "WatchTree" } do
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
		local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
		if isClick or input.KeyCode == biteKey then
			local ray = screenRay(UserInputService:GetMouseLocation(), false)
			if ray then
				clickAt(ray, false)
				refreshSlots()
			end
		elseif input.KeyCode == rootKey then
			Remotes.event("Root"):FireServer()
		elseif slotKeys[input.KeyCode] then
			pressSlot(slotKeys[input.KeyCode])
			refreshSlots()
		end
	end)
	-- A tap (not a drag, and not on a button) bites where it lands.
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUi)
		if processedByUi then
			return
		end
		local ray = screenRay(position, true)
		if ray then
			clickAt(ray, true)
			refreshSlots()
		end
	end)

	local lastRefresh = 0
	local watchStarted = os.clock()
	player:GetAttributeChangedSignal("WatchTree"):Connect(function()
		watchStarted = os.clock()
	end)
	RunService.RenderStepped:Connect(function()
		updateTreeCamera(watchStarted)
		updateHighlight()
		-- Timers (venom, mantis) run out without an attribute change.
		local now = os.clock()
		if now - lastRefresh > 0.25 then
			lastRefresh = now
			refreshSlots()
		end
	end)
end

return Controls
