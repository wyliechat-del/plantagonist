--[[
	Placeholder plant look, built from parts on a normal Roblox character.

	The character's legs stay visible as brown roots (so the run animation
	still works); the rest of the body is hidden and a pot, stem and snapping
	head are welded on. The look has named attachments (Head, Jaw, Back, Tail,
	Hands, Feet) where loaded power ups show, so final Blender models only need
	the same attachment names.

	Everything is built at scale 1; the whole character is scaled per level
	with Model:ScaleTo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Plants = require(ReplicatedStorage.Shared.Config.Plants)
local PowerUps = require(ReplicatedStorage.Shared.Config.PowerUps)

local Util = require(script.Parent.Util)

local PlantModel = {}

local VISUAL = "PlantVisual"
local ROOT_COLOUR = Color3.fromRGB(120, 80, 45)
local HIDDEN = 1
local INVISIBLE = 0.85

local function isRootPart(part: BasePart): boolean
	return string.find(part.Name, "Leg") ~= nil or string.find(part.Name, "Foot") ~= nil
end

local function weldTo(part: BasePart, anchor: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
end

local function visualPart(
	parent: Instance,
	anchor: BasePart,
	props: { [string]: any },
	offset: CFrame
): Part
	props.Anchored = false
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.Massless = true
	props.CFrame = anchor.CFrame * offset
	props.Parent = parent
	local part = Util.part(props)
	weldTo(part, anchor)
	return part
end

local function attachment(parent: BasePart, name: string, position: Vector3)
	local item = Instance.new("Attachment")
	item.Name = name
	item.Position = position
	item.Parent = parent
end

-- Hides the default body, colours the legs as roots and adds the plant look.
function PlantModel.dress(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	assert(root, "character has no HumanoidRootPart")
	for _, item in character:GetDescendants() do
		local isFace = item:IsA("Decal") and item.Parent ~= nil and item.Parent.Name == "Head"
		local isClothing = item:IsA("Accessory") or item:IsA("Clothing") or item:IsA("ShirtGraphic")
		if isFace or isClothing or item:IsA("BodyColors") then
			item:Destroy()
		end
	end
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part ~= root then
			if isRootPart(part) then
				part.Color = ROOT_COLOUR
				part.Material = Enum.Material.Wood
			else
				part.Transparency = HIDDEN
			end
		end
	end
	-- Accessories that load later are removed too.
	character.ChildAdded:Connect(function(child)
		if child:IsA("Accessory") or child:IsA("Clothing") or child:IsA("BodyColors") then
			task.defer(function()
				child:Destroy()
			end)
		end
	end)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local old = character:FindFirstChild(VISUAL)
	if old then
		old:Destroy()
	end
	local visual = Instance.new("Model")
	visual.Name = VISUAL
	visual.Parent = character

	local pot = visualPart(visual, root, {
		Name = "Pot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 2.4, 2.4),
		Color = Util.colour(Plants.potColour),
		Material = Enum.Material.Slate,
	}, CFrame.new(0, -0.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
	visualPart(visual, root, {
		Name = "Stem",
		Size = Vector3.new(0.5, 1.6, 0.5),
		Color = Util.colour(Plants.stemColour),
	}, CFrame.new(0, 1.4, 0))
	local head = visualPart(visual, root, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.6, 2.6, 2.6),
		Color = Util.colour(Plants.headColour),
	}, CFrame.new(0, 3, 0))
	visualPart(visual, root, {
		Name = "Mouth",
		Size = Vector3.new(2.2, 0.5, 1.3),
		Color = Util.colour(Plants.mouthColour),
	}, CFrame.new(0, 2.7, -1))
	visualPart(visual, root, {
		Name = "UpperJaw",
		Size = Vector3.new(2.3, 0.4, 1.4),
		Color = Util.colour(Plants.headColour),
	}, CFrame.new(0, 3.3, -1) * CFrame.Angles(math.rad(15), 0, 0))

	-- The pot is a cylinder turned on its side, so its local axes are rotated:
	-- local X points up, local Y points sideways.
	attachment(head, "Head", Vector3.new(0, 1.2, 0))
	attachment(head, "Jaw", Vector3.new(0, -0.3, -1.4))
	attachment(pot, "Back", Vector3.new(0.4, 0, 1.3))
	attachment(pot, "Tail", Vector3.new(-0.4, 0, 1.4))
	attachment(pot, "Hands", Vector3.new(0.3, 1.4, 0))
	attachment(pot, "Feet", Vector3.new(-1.1, 0, 0))
end

-- Shows a small coloured marker at the attachment of each loaded power up.
-- `ids` is the list of power up ids in the plant's slots.
function PlantModel.showPowerUps(character: Model, ids: { string })
	local visual = character:FindFirstChild(VISUAL)
	if visual == nil then
		return
	end
	for _, item in visual:GetChildren() do
		if item.Name == "PowerUpMarker" then
			item:Destroy()
		end
	end
	local scale = character:GetScale()
	local usedAt: { [string]: number } = {}
	for _, id in ids do
		local creature = PowerUps.creatures[id]
		local point = creature and visual:FindFirstChild(creature.showAt, true) :: Attachment?
		if
			creature
			and point
			and point:IsA("Attachment")
			and point.Parent
			and point.Parent:IsA("BasePart")
		then
			local count = (usedAt[creature.showAt] or 0) + 1
			usedAt[creature.showAt] = count
			local marker = Util.part({
				Name = "PowerUpMarker",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.7 * scale,
				Color = Util.colour(PowerUps.families[creature.family].colour),
				Material = Enum.Material.Neon,
				Anchored = false,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Massless = true,
				CFrame = point.WorldCFrame * CFrame.new((count - 1) * 0.6 * scale, 0, 0),
				Parent = visual,
			})
			weldTo(marker, point.Parent)
		end
	end
end

local function setVisible(character: Model, transparency: number)
	local visual = character:FindFirstChild(VISUAL)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			local inVisual = visual ~= nil and part:IsDescendantOf(visual)
			local isRoot = part.Parent == character and isRootPart(part)
			if inVisual or isRoot then
				part.Transparency = transparency
			end
		end
	end
end

-- Stick insect: nearly invisible.
function PlantModel.setInvisible(character: Model, on: boolean)
	setVisible(character, if on then INVISIBLE else 0)
	character:SetAttribute("Invisible", on)
	local root = character:FindFirstChild("HumanoidRootPart")
	local label = root and root:FindFirstChild("Label")
	if not on and label and label:IsA("BillboardGui") then
		label.Enabled = true
	end
end

-- Fully hidden (while the player watches their new tree grow).
function PlantModel.setHidden(character: Model, on: boolean)
	setVisible(character, if on then HIDDEN else 0)
	character:SetAttribute("Invisible", on)
	local root = character:FindFirstChild("HumanoidRootPart")
	local label = root and root:FindFirstChild("Label")
	if label and label:IsA("BillboardGui") then
		label.Enabled = not on
	end
end

-- Blowfish: a spiky ball round the plant.
function PlantModel.setBall(character: Model, on: boolean)
	local existing = character:FindFirstChild("BlowfishBall")
	if existing then
		existing:Destroy()
	end
	if not on then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local scale = character:GetScale()
	local ball = Util.part({
		Name = "BlowfishBall",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 7 * scale,
		Color = Util.colour(PowerUps.families.SpecialMove.colour),
		Transparency = 0.5,
		Material = Enum.Material.ForceField,
		Anchored = false,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		CFrame = root.CFrame * CFrame.new(0, 1 * scale, 0),
		Parent = character,
	})
	weldTo(ball, root)
end

-- Bee: a venom sack stuck to the plant while the venom lasts.
function PlantModel.setVenomSack(character: Model, on: boolean)
	local existing = character:FindFirstChild("VenomSack", true)
	if existing then
		existing:Destroy()
	end
	if not on then
		return
	end
	local visual = character:FindFirstChild(VISUAL)
	local head = visual and visual:FindFirstChild("Head") :: BasePart?
	if head == nil then
		return
	end
	local scale = character:GetScale()
	local sack = Util.part({
		Name = "VenomSack",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.2 * scale,
		Color = Util.colour(PowerUps.families.Venom.colour),
		Material = Enum.Material.Neon,
		Anchored = false,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		CFrame = head.CFrame * CFrame.new(1.3 * scale, 0.4 * scale, 0),
		Parent = visual,
	})
	weldTo(sack, head)
end

-- Name and level label above the plant.
function PlantModel.setLabel(character: Model, text: string)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local gui = root:FindFirstChild("Label") :: BillboardGui?
	if gui == nil then
		Util.label(root, text, 5)
		gui = root:FindFirstChild("Label") :: BillboardGui?
	end
	if gui then
		gui.StudsOffset = Vector3.new(0, 4.5 * character:GetScale(), 0)
		local textLabel = gui:FindFirstChildOfClass("TextLabel")
		if textLabel then
			textLabel.Text = text
		end
	end
end

return PlantModel
