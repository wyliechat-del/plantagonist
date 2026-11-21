--[[
	The HUD: the tree ring stat bar (level name, rings, progress to the next
	level), pop-up messages, the crosshair and a full-screen flash.
	Values come from attributes the server sets on the local Player.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Controls = require(ReplicatedStorage.Shared.Config.Controls)
local Levels = require(ReplicatedStorage.Shared.Config.Levels)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Ui = require(script.Parent.Ui)

local Hud = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local ringHolder: Frame
local levelLabel: TextLabel
local fill: Frame
local fertiliserBadge: TextLabel
local messages: Frame
local flashFrame: Frame
local nextOrder = 0

local MESSAGE_COLOURS = {
	good = Color3.fromRGB(150, 255, 140),
	bad = Color3.fromRGB(255, 140, 140),
	award = Color3.fromRGB(255, 220, 90),
	event = Color3.fromRGB(150, 200, 255),
	info = Color3.fromRGB(255, 255, 255),
}

function Hud.gui(): ScreenGui
	return gui
end

-- Concentric circles, one per level, like the rings of a tree.
local function drawRings(level: number)
	ringHolder:ClearAllChildren()
	for ring = level, 1, -1 do
		local share = ring / #Levels.list
		Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(share, share),
			BackgroundColor3 = if ring % 2 == 0
				then Color3.fromRGB(200, 150, 90)
				else Color3.fromRGB(160, 110, 60),
			Parent = ringHolder,
		}, { Ui.corner() })
	end
end

local function refresh()
	local rings = player:GetAttribute("Rings") or 0
	local level = player:GetAttribute("Level") or 1
	local name = player:GetAttribute("LevelName") or Levels.list[1].name
	local low = Levels.list[level].minRings
	local nextInfo = Levels.list[level + 1]
	local high = if nextInfo then nextInfo.minRings else Levels.rootRings
	local share = math.clamp((rings - low) / math.max(high - low, 1), 0, 1)
	if rings >= Levels.rootRings then
		levelLabel.Text = `{name}  ·  {rings} rings  ·  Ready to take root!`
	else
		levelLabel.Text = `Lv {level} {name}  ·  {rings} rings`
	end
	fill.Size = UDim2.fromScale(share, 1)
	drawRings(level)
	fertiliserBadge.Visible = player:GetAttribute("Fertilised") == true
end

-- Shows a short message near the top of the screen.
function Hud.message(text: string, kind: string?)
	nextOrder += 1
	local label = Ui.make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = MESSAGE_COLOURS[kind or "info"] or MESSAGE_COLOURS.info,
		TextStrokeTransparency = 0.3,
		LayoutOrder = nextOrder,
		Parent = messages,
	})
	task.delay(Controls.messageSeconds, function()
		local fade = TweenService:Create(
			label,
			TweenInfo.new(0.5),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
	end)
	-- Keep at most 4 messages.
	local labels = {}
	for _, child in messages:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	table.sort(labels, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #labels - 4 do
		labels[index]:Destroy()
	end
end

-- A white flash over the whole screen (taking root).
function Hud.flash()
	flashFrame.BackgroundTransparency = 0
	TweenService:Create(flashFrame, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
end

local function updateScale(scale: UIScale)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local size = camera.ViewportSize
	local short = math.min(size.X, size.Y)
	scale.Scale = math.clamp(short / Controls.referenceShortSide, 0.75, Controls.maxUiScale)
end

function Hud.start()
	gui = Ui.make("ScreenGui", {
		Name = "PlantagonistHud",
		ResetOnSpawn = false,
		-- Full screen, so the crosshair sits exactly where the camera looks.
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local scale = Ui.make("UIScale", { Parent = gui })
	updateScale(scale)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			updateScale(scale)
		end)
	end

	local bar = Ui.make("Frame", {
		Name = "TreeRingBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(300, 44),
		BackgroundColor3 = Color3.fromRGB(60, 40, 25),
		BackgroundTransparency = 0.2,
		Parent = gui,
	}, { Ui.corner(UDim.new(0, 12)) })
	local ringIcon = Ui.make("Frame", {
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Color3.fromRGB(230, 190, 130),
		Parent = bar,
	}, { Ui.corner() })
	ringHolder = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = ringIcon,
	})
	levelLabel = Ui.make("TextLabel", {
		Position = UDim2.fromOffset(46, 3),
		Size = UDim2.new(1, -52, 0, 22),
		BackgroundTransparency = 1,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = bar,
	})
	local track = Ui.make("Frame", {
		Position = UDim2.fromOffset(46, 28),
		Size = UDim2.new(1, -56, 0, 10),
		BackgroundColor3 = Color3.fromRGB(30, 20, 10),
		Parent = bar,
	}, { Ui.corner() })
	fill = Ui.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(120, 210, 90),
		Parent = track,
	}, { Ui.corner() })
	fertiliserBadge = Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 6, 0.5, 0),
		Size = UDim2.fromOffset(90, 22),
		BackgroundColor3 = Color3.fromRGB(110, 75, 40),
		Text = "Fertilised",
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 230, 150),
		Visible = false,
		Parent = bar,
	}, { Ui.corner(UDim.new(0, 8)) })

	messages = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(420, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.make(
			"UIListLayout",
			{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }
		),
	})

	-- Crosshair in the middle of the screen.
	Ui.make("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.corner(), Ui.stroke(Color3.new(1, 1, 1), 2) })

	flashFrame = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	})

	for _, name in { "Rings", "Level", "LevelName", "Fertilised" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()

	Remotes.event("Notify").OnClientEvent:Connect(function(text, kind)
		if type(text) == "string" then
			Hud.message(text, if type(kind) == "string" then kind else nil)
		end
	end)
end

return Hud
