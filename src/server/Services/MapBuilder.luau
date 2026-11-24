--[[
	Builds the blockout map from Config/Map when the server starts: ground for
	each territory, the conservatory and safe field, river and swamp, caves,
	forest and grassland. Everything is plain parts in Workspace.Map, so custom
	art can replace it later.

	Parts with a `RaisedMaxLevel` attribute (bridges, lily pads) cancel water
	and mud slowdown for plants up to that level.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Build = require(ReplicatedStorage.Shared.Config.Build)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local MapRules = require(ReplicatedStorage.Shared.Rules.Map)

local Util = require(script.Parent.Util)

local MapBuilder = {}

local folder: Folder
local rayParams = RaycastParams.new()

local GROUND = Map.groundY
local BARK = Color3.fromRGB(110, 75, 45)
local LEAVES = Color3.fromRGB(50, 130, 55)

local function tree(parent: Instance, x: number, z: number, height: number, crown: number)
	local base = MapBuilder.groundY(x, z)
	Util.part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 2.5, 2.5),
		CFrame = CFrame.new(x, base + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = BARK,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	Util.part({
		Name = "Crown",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(crown, crown, crown),
		Position = Vector3.new(x, base + height, z),
		Color = LEAVES,
		Material = Enum.Material.Grass,
		Parent = parent,
	})
end

local function buildGround()
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = folder
	local half = Map.halfSize
	for name, territory in Map.territories do
		Util.part({
			Name = name,
			Size = Vector3.new(half, 4, half),
			Position = Vector3.new(
				territory.signX * half / 2,
				GROUND - 2,
				territory.signZ * half / 2
			),
			Color = Util.colour(territory.colour),
			Material = Enum.Material.Grass,
			Parent = ground,
		})
	end
	-- Invisible walls round the edge.
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local sx, sz = side[1], side[2]
		Util.part({
			Name = "EdgeWall",
			Size = if sx ~= 0
				then Vector3.new(2, Map.wallHeight, half * 2)
				else Vector3.new(half * 2, Map.wallHeight, 2),
			Position = Vector3.new(sx * (half + 1), GROUND + Map.wallHeight / 2, sz * (half + 1)),
			Transparency = 1,
			Parent = ground,
		})
	end
end

local function buildField()
	local field = Instance.new("Folder")
	field.Name = "Field"
	field.Parent = folder
	local radius = Map.Field.radius
	Util.part({
		Name = "Lawn",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = CFrame.new(0, GROUND + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(140, 210, 110),
		Material = Enum.Material.Grass,
		CanCollide = false,
		Parent = field,
	})
	-- Ring of trees with 12 gaps.
	local angle = 0
	while angle < 360 do
		if not MapRules.isExitAngle(Map, angle) then
			local radians = math.rad(angle)
			tree(field, math.cos(radians) * (radius + 1), math.sin(radians) * (radius + 1), 9, 7)
		end
		angle += Map.Field.treeSpacingDegrees
	end
end

-- Invisible walls with a doorway in each side, and a lid on top.
local function conservatoryCollision(house: Folder, visible: boolean)
	local c = Map.Conservatory
	local props = if visible
		then {
			Color = Util.colour(c.colours.Glass),
			Transparency = c.glassTransparency,
			Material = Enum.Material.Glass,
		}
		else { Transparency = 1 }
	local sideLength = c.halfSize * 2
	local segment = (sideLength - c.doorWidth) / 2
	local offset = c.halfSize - c.wallThickness / 2
	for _, facing in { 0, 90, 180, 270 } do
		local rotation = CFrame.Angles(0, math.rad(facing), 0)
		local function wall(name: string, size: Vector3, position: Vector3)
			local part = table.clone(props)
			part.Name = name
			part.Size = size
			part.CFrame = rotation * CFrame.new(position)
			part.Parent = house
			Util.part(part)
		end
		local along = c.doorWidth / 2 + segment / 2
		local wallSize = Vector3.new(segment, c.height, c.wallThickness)
		wall("Wall", wallSize, Vector3.new(-along, GROUND + c.height / 2, offset))
		wall("Wall", wallSize, Vector3.new(along, GROUND + c.height / 2, offset))
		wall(
			"Lintel",
			Vector3.new(c.doorWidth, c.height - c.doorHeight, c.wallThickness),
			Vector3.new(0, GROUND + c.doorHeight + (c.height - c.doorHeight) / 2, offset)
		)
	end
	local roof = table.clone(props)
	roof.Name = "Roof"
	roof.Size = Vector3.new(sideLength, 1, sideLength)
	roof.Position = Vector3.new(0, GROUND + c.height + 0.5, 0)
	roof.Parent = house
	Util.part(roof)
end

-- Reads a property that may not exist on this Studio version.
local function tryRead(instance: Instance, property: string): any
	local ok, value = pcall(function()
		return (instance :: any)[property]
	end)
	return if ok then value else nil
end

-- An image address from a string property or a Content property.
local function addressOf(value: any): string?
	if type(value) == "string" and value ~= "" then
		return value
	end
	if typeof(value) == "Content" then
		local uri = (value :: any).Uri
		if type(uri) == "string" and uri ~= "" then
			return uri
		end
	end
	return nil
end

-- The image on an imported part. An asset id set in Config wins; otherwise
-- look on the part, the parts and SurfaceAppearances inside it, under the
-- property names different Studio versions use.
local function imageOf(mesh: Instance, name: string): string?
	local id = Map.Conservatory.imageIds[name]
	if id and id > 0 then
		return `rbxassetid://{id}`
	end
	local candidates = { mesh }
	for _, child in mesh:GetDescendants() do
		table.insert(candidates, child)
	end
	for _, instance in candidates do
		for _, property in { "TextureID", "TextureContent", "ColorMap", "ColorMapContent" } do
			local address = addressOf(tryRead(instance, property))
			if address then
				return address
			end
		end
	end
	return nil
end

-- Swaps an imported flat image part (roof or sign) for a thin invisible part
-- with the same image as decals. Decals show the see-through parts of an
-- image; mesh textures don't.
local function asDecal(house: Folder, mesh: BasePart, name: string)
	local c = Map.Conservatory
	local image = imageOf(mesh, name)
	if image == nil then
		local found = {}
		for _, child in mesh:GetDescendants() do
			table.insert(found, child.ClassName)
		end
		warn(
			`[MapBuilder] no image found on {mesh:GetFullName()} ({mesh.ClassName}; inside: {table.concat(
				found,
				", "
			)})`
		)
		return
	end
	local size = mesh.Size
	local position = mesh.Position
	local faces: { Enum.NormalId }
	local partSize: Vector3
	if name == "Roof" then
		faces = { Enum.NormalId.Top, Enum.NormalId.Bottom }
		partSize = Vector3.new(size.X, c.decalThickness, size.Z)
		position += Vector3.new(0, c.decalOffset, 0)
	else
		-- Signs face away from the middle (outside) or towards it (inside).
		local away = if name == "SignOutside" then 1 else -1
		if size.X < size.Z then
			local direction = away * math.sign(position.X)
			faces = { if direction > 0 then Enum.NormalId.Right else Enum.NormalId.Left }
			partSize = Vector3.new(c.decalThickness, size.Y, size.Z)
			position += Vector3.new(direction * c.decalOffset, 0, 0)
		else
			local direction = away * math.sign(position.Z)
			faces = { if direction > 0 then Enum.NormalId.Back else Enum.NormalId.Front }
			partSize = Vector3.new(size.X, size.Y, c.decalThickness)
			position += Vector3.new(0, 0, direction * c.decalOffset)
		end
	end
	local holder = Util.part({
		Name = name,
		Size = partSize,
		Position = position,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = house,
	})
	for _, face in faces do
		local decal = Instance.new("Decal")
		decal.Texture = image
		decal.Face = face
		decal.Parent = holder
	end
	mesh:Destroy()
end

-- Places a copy of the imported conservatory model and styles its parts by
-- name. The model lives in the place file (ServerStorage), not in Rojo:
-- Rojo 7.5 can't read models saved by current Studio. Returns false when
-- the model hasn't been imported yet.
local function placeConservatoryModel(house: Folder): boolean
	local c = Map.Conservatory
	local source = ServerStorage:FindFirstChild(c.modelName)
	if source == nil or not source:IsA("Model") then
		return false
	end
	local model = source:Clone()
	model.Name = "ConservatoryModel"
	-- The importer may change units, so scale to the right width, then sit
	-- the model centred on the ground.
	local _, size = model:GetBoundingBox()
	local width = math.max(size.X, size.Z)
	if width > 0 then
		model:ScaleTo(model:GetScale() * c.halfSize * 2 / width)
	end
	local box, scaled = model:GetBoundingBox()
	model:TranslateBy(Vector3.new(0, GROUND + scaled.Y / 2, 0) - box.Position)
	local decals = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			-- The importer names parts like "Glass_Node" or "SignOutside3";
			-- the leading letters say what the part is.
			local name = string.match(part.Name, "^%a+") or part.Name
			local colour = c.colours[name]
			if colour then
				part.Color = Util.colour(colour)
			end
			if name == "Glass" then
				part.Transparency = c.glassTransparency
				part.Material = Enum.Material.Glass
				part.CastShadow = false
			elseif name == "Roof" or name == "SignOutside" or name == "SignInside" then
				table.insert(decals, { part = part, name = name })
			end
		end
	end
	for _, item in decals do
		asDecal(house, item.part, item.name)
	end
	model.Parent = house
	return true
end

-- Spot lights under the roof in the stained glass colours.
local function roofLights(house: Folder)
	local c = Map.Conservatory
	local lights = c.roofLights
	local count = lights.perSide
	local step = c.halfSize * 2 / count
	local index = 0
	for row = 1, count do
		for column = 1, count do
			index += 1
			local x = -c.halfSize + step * (column - 0.5)
			local z = -c.halfSize + step * (row - 0.5)
			local holder = Util.part({
				Name = "RoofLight",
				Size = Vector3.new(1, 1, 1),
				Position = Vector3.new(x, GROUND + c.height - lights.belowRoof, z),
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Parent = house,
			})
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Bottom
			light.Range = lights.range
			light.Angle = lights.angle
			light.Brightness = lights.brightness
			light.Shadows = false
			light.Color = Util.colour(lights.colours[(index - 1) % #lights.colours + 1])
			light.Parent = holder
		end
	end
end

local function buildConservatory()
	local house = Instance.new("Folder")
	house.Name = "Conservatory"
	house.Parent = folder
	local c = Map.Conservatory
	local hasModel = placeConservatoryModel(house)
	conservatoryCollision(house, not hasModel)
	if hasModel then
		roofLights(house)
	end
	-- Potted plants and a sculpture for decoration.
	for index = 1, 8 do
		local radians = math.rad(index * 45)
		local x, z = math.cos(radians) * (c.halfSize - 6), math.sin(radians) * (c.halfSize - 6)
		Util.part({
			Name = "Pot",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 4, 4),
			CFrame = CFrame.new(x, GROUND + 1.5, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(190, 100, 60),
			Parent = house,
		})
		Util.part({
			Name = "Plant",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(5, 5, 5),
			Position = Vector3.new(x, GROUND + 5, z),
			Color = LEAVES,
			CanCollide = false,
			Parent = house,
		})
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ConservatorySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, GROUND + 0.5, 0)
	spawn.Color = Color3.fromRGB(240, 220, 120)
	spawn.Parent = house

	-- Flag showing the build number, next to the spawn pad.
	local z = Build.offsetFromSpawn
	Util.part({
		Name = "FlagPole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(Build.poleHeight, 0.4, 0.4),
		CFrame = CFrame.new(0, GROUND + Build.poleHeight / 2, z)
			* CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(230, 230, 230),
		Material = Enum.Material.Metal,
		Parent = house,
	})
	local flag = Util.part({
		Name = "BuildFlag",
		Size = Vector3.new(Build.flagWidth, Build.flagHeight, 0.2),
		Position = Vector3.new(
			Build.flagWidth / 2,
			GROUND + Build.poleHeight - Build.flagHeight / 2,
			z
		),
		Color = Color3.fromRGB(60, 140, 60),
		CanCollide = false,
		Parent = house,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = flag
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = `Build {Build.number}\n{Build.date}`
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
	end
end

local function buildRiverAndSwamp()
	local wet = Instance.new("Folder")
	wet.Name = "RiverAndSwamp"
	wet.Parent = folder
	local river = Map.River
	local riverWidth = river.maxZ - river.minZ
	local riverMidZ = (river.minZ + river.maxZ) / 2
	Util.part({
		Name = "River",
		Size = Vector3.new(river.maxX - river.minX, 0.4, riverWidth),
		Position = Vector3.new((river.minX + river.maxX) / 2, GROUND + 0.2, riverMidZ),
		Color = Color3.fromRGB(60, 130, 200),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
		Parent = wet,
	})
	for _, x in river.bridgeXs do
		local length = riverWidth + 6
		local bridge = Util.part({
			Name = "Bridge",
			Size = Vector3.new(river.bridgeWidth, river.bridgeHeight, length),
			Position = Vector3.new(x, GROUND + river.bridgeHeight / 2, riverMidZ),
			Color = BARK,
			Material = Enum.Material.Wood,
			Parent = wet,
		})
		bridge:SetAttribute("RaisedMaxLevel", 6)
		for _, direction in { 1, -1 } do
			local ramp = Instance.new("WedgePart")
			ramp.Name = "BridgeRamp"
			ramp.Anchored = true
			ramp.Size = Vector3.new(river.bridgeWidth, river.bridgeHeight, 8)
			ramp.CFrame = CFrame.new(
				x,
				GROUND + river.bridgeHeight / 2,
				riverMidZ + direction * (length / 2 + 4)
			) * CFrame.Angles(0, if direction == 1 then math.pi else 0, 0)
			ramp.Color = BARK
			ramp.Material = Enum.Material.Wood
			ramp:SetAttribute("RaisedMaxLevel", 6)
			ramp.Parent = wet
		end
	end
	local swamp = Map.Swamp
	Util.part({
		Name = "Mud",
		Size = Vector3.new(swamp.maxX - swamp.minX, 0.2, swamp.maxZ - swamp.minZ),
		Position = Vector3.new(
			(swamp.minX + swamp.maxX) / 2,
			GROUND + 0.1,
			(swamp.minZ + swamp.maxZ) / 2
		),
		Color = Color3.fromRGB(90, 85, 50),
		Material = Enum.Material.Mud,
		CanCollide = false,
		Parent = wet,
	})
	for _ = 1, swamp.lilyPads do
		local x = swamp.minX + Util.random() * (swamp.maxX - swamp.minX)
		local z = swamp.minZ + Util.random() * (swamp.maxZ - swamp.minZ)
		local pad = Util.part({
			Name = "LilyPad",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 6, 6),
			CFrame = CFrame.new(x, GROUND + 0.3, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(80, 170, 70),
			Parent = wet,
		})
		-- Only small plants hop across on lily pads.
		pad:SetAttribute("RaisedMaxLevel", Map.Swamp.slowFromLevel - 1)
	end
end

local function buildHills()
	local hills = Instance.new("Folder")
	hills.Name = "Hills"
	hills.Parent = folder
	local rock = Color3.fromRGB(130, 120, 100)
	local caves = Map.Caves
	for _, cave in caves.list do
		local width = 60
		local sideWidth = (width - caves.width) / 2
		for _, side in { -1, 1 } do
			Util.part({
				Name = "CaveHill",
				Size = Vector3.new(cave.length, cave.hillHeight, sideWidth),
				Position = Vector3.new(
					cave.x,
					GROUND + cave.hillHeight / 2,
					cave.z + side * (caves.width / 2 + sideWidth / 2)
				),
				Color = rock,
				Material = Enum.Material.Rock,
				Parent = hills,
			})
		end
		Util.part({
			Name = "CaveRoof",
			Size = Vector3.new(cave.length, cave.hillHeight - caves.clearance, caves.width),
			Position = Vector3.new(
				cave.x,
				GROUND + caves.clearance + (cave.hillHeight - caves.clearance) / 2,
				cave.z
			),
			Color = rock,
			Material = Enum.Material.Rock,
			Parent = hills,
		})
	end
	for _, hill in caves.hills do
		for _, direction in { 1, -1 } do
			local slope = Instance.new("WedgePart")
			slope.Name = "Hill"
			slope.Anchored = true
			slope.Size = Vector3.new(hill.size, hill.height, hill.size / 2)
			slope.CFrame = CFrame.new(
				hill.x,
				GROUND + hill.height / 2,
				hill.z + direction * hill.size / 4
			) * CFrame.Angles(0, if direction == 1 then math.pi else 0, 0)
			slope.Color = Color3.fromRGB(150, 140, 100)
			slope.Material = Enum.Material.Grass
			slope.Parent = hills
		end
	end
end

local function buildForest()
	local forest = Instance.new("Folder")
	forest.Name = "Forest"
	forest.Parent = folder
	local logs = Map.Forest.logs
	local placed = 0
	local tries = 0
	while placed < Map.Forest.trees and tries < Map.Forest.trees * 10 do
		tries += 1
		local x, z = MapRules.randomPointIn(Map, "Forest", Util.random)
		local clear = true
		for _, log in logs do
			if math.abs(x - log.x) < log.length / 2 + 8 and math.abs(z - log.z) < 12 then
				clear = false
			end
		end
		if clear then
			tree(forest, x, z, 14 + Util.random() * 10, 10 + Util.random() * 6)
			placed += 1
		end
	end
	local clearance = Map.Forest.logClearance
	for _, log in logs do
		for _, side in { -1, 1 } do
			Util.part({
				Name = "LogSide",
				Size = Vector3.new(log.length, clearance, 1.5),
				Position = Vector3.new(log.x, GROUND + clearance / 2, log.z + side * 3.75),
				Color = BARK,
				Material = Enum.Material.Wood,
				Parent = forest,
			})
		end
		Util.part({
			Name = "LogTop",
			Size = Vector3.new(log.length, 2, 9),
			Position = Vector3.new(log.x, GROUND + clearance + 1, log.z),
			Color = BARK,
			Material = Enum.Material.Wood,
			Parent = forest,
		})
	end
end

local function buildGrassland()
	local grass = Instance.new("Folder")
	grass.Name = "Grassland"
	grass.Parent = folder
	for _ = 1, Map.Grassland.grassPatches do
		local x, z = MapRules.randomPointIn(Map, "Grassland", Util.random)
		Util.part({
			Name = "TallGrass",
			Size = Vector3.new(16, 6, 16),
			Position = Vector3.new(x, GROUND + 3, z),
			Color = Color3.fromRGB(150, 200, 80),
			Material = Enum.Material.Grass,
			Transparency = 0.35,
			CanCollide = false,
			CanQuery = false,
			Parent = grass,
		})
	end
	for _, field in Map.Grassland.cowFields do
		local half = field.size / 2
		local step = 8
		local offset = -half
		while offset <= half do
			for _, post in
				{
					Vector3.new(field.x + offset, 0, field.z - half),
					Vector3.new(field.x + offset, 0, field.z + half),
					Vector3.new(field.x - half, 0, field.z + offset),
					Vector3.new(field.x + half, 0, field.z + offset),
				}
			do
				Util.part({
					Name = "FencePost",
					Size = Vector3.new(0.6, 3, 0.6),
					Position = Vector3.new(post.X, GROUND + 1.5, post.Z),
					Color = Color3.fromRGB(200, 180, 140),
					Material = Enum.Material.Wood,
					Parent = grass,
				})
			end
			offset += step
		end
	end
end

-- The ground height at (x, z), found with a ray down onto the map.
function MapBuilder.groundY(x: number, z: number): number
	if folder == nil then
		return GROUND
	end
	local result =
		workspace:Raycast(Vector3.new(x, GROUND + 200, z), Vector3.new(0, -400, 0), rayParams)
	return if result then result.Position.Y else GROUND
end

-- A random spot inside the conservatory, where plants spawn.
function MapBuilder.spawnPosition(): Vector3
	local inner = Map.Conservatory.halfSize - 10
	local x = (Util.random() * 2 - 1) * inner
	local z = (Util.random() * 2 - 1) * inner
	return Vector3.new(x, GROUND + 4, z)
end

function MapBuilder.raycastParams(): RaycastParams
	return rayParams
end

function MapBuilder.start()
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Map"
	folder.Parent = workspace
	rayParams.FilterType = Enum.RaycastFilterType.Include

	buildGround()
	buildHills()
	buildRiverAndSwamp()
	-- The ground ray only looks at walkable ground, not trees or grass.
	rayParams.FilterDescendantsInstances = {
		folder:FindFirstChild("Ground") :: Instance,
		folder:FindFirstChild("Hills") :: Instance,
		folder:FindFirstChild("RiverAndSwamp") :: Instance,
	}
	buildField()
	buildConservatory()
	buildForest()
	buildGrassland()
end

return MapBuilder
