--[[
	Builds the blockout map from Config/Map when the server starts: ground for
	each territory, the conservatory and safe field, the River quarter (river,
	bridges, ford, marsh, lily pads, path, gate, hiding grass), caves,
	forest and grassland. Everything is plain parts in Workspace.Map, so custom
	art can replace it later.

	Parts with a `RaisedMaxLevel` attribute (bridges, ford rocks, lily pads)
	cancel water and mud slowdown for plants up to that level. Lily pads also
	carry `LilyPad`, which the client uses for the frog hop.
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
			local colourIndex = lights.pattern[(index - 1) % #lights.pattern + 1]
			light.Color = Util.colour(lights.colours[colourIndex])
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

-- A frame at ground point (x, z) whose X axis runs along (ax, az), tilted up
-- by `pitch` radians, and whose Y axis points (nearly) up.
local function alongFrame(position: Vector3, ax: number, az: number, pitch: number): CFrame
	local cos, sin = math.cos(pitch), math.sin(pitch)
	local xVector = Vector3.new(ax * cos, sin, az * cos)
	local yVector = Vector3.new(-ax * sin, cos, -az * sin)
	return CFrame.fromMatrix(position, xVector, yVector)
end

-- Direction of the river at (x, z), and the direction straight across it.
local function riverAxes(x: number, z: number): (number, number, number, number)
	local _, dx, dz = MapRules.closestOnLine(Map.River.centreLine, x, z)
	return dx, dz, -dz, dx
end

local function setTerrainWaterLook()
	local river = Map.River
	local terrain = workspace.Terrain
	terrain.WaterColor = Util.colour(river.waterColour)
	terrain.WaterTransparency = river.waterTransparency
	terrain.WaterReflectance = river.waterReflectance
	terrain.WaterWaveSize = river.waveSize
	terrain.WaterWaveSpeed = river.waveSpeed
end

local function buildRiver(parent: Instance)
	local river = Map.River
	local points = river.centreLine
	local terrain = workspace.Terrain
	local y = GROUND + river.depth / 2
	if river.terrainWater then
		setTerrainWaterLook()
	end
	for i = 1, #points do
		local px, pz = points[i][1], points[i][2]
		if river.terrainWater then
			-- Round joins between the straight pieces.
			terrain:FillCylinder(
				CFrame.new(px, y, pz),
				river.depth,
				river.width / 2,
				Enum.Material.Water
			)
		end
		if i < #points then
			local qx, qz = points[i + 1][1], points[i + 1][2]
			local length = math.sqrt((qx - px) ^ 2 + (qz - pz) ^ 2)
			local frame = alongFrame(
				Vector3.new((px + qx) / 2, y, (pz + qz) / 2),
				(qx - px) / length,
				(qz - pz) / length,
				0
			)
			if river.terrainWater then
				terrain:FillBlock(
					frame,
					Vector3.new(length, river.depth, river.width),
					Enum.Material.Water
				)
			else
				Util.part({
					Name = "River",
					Size = Vector3.new(length + river.width / 2, river.depth, river.width),
					CFrame = frame,
					Color = Util.colour(river.plainColour),
					Material = Enum.Material.Glass,
					Transparency = 0.3,
					CanCollide = false,
					CanQuery = false,
					Parent = parent,
				})
			end
		end
	end
end

-- Stone moon bridge: a steep arch of deck pieces with low walls each side.
local function buildMoonBridge(parent: Instance)
	local bridge = Map.MoonBridge
	local model = Instance.new("Model")
	model.Name = "MoonBridge"
	model.Parent = parent
	local riverX, riverZ, ax, az = riverAxes(bridge.x, bridge.z)
	local step = bridge.span / bridge.segments
	local wallOffset = bridge.width / 2 - bridge.parapetThickness / 2
	for i = 0, bridge.segments - 1 do
		local from = -bridge.span / 2 + i * step
		local to = from + step
		local h0 = MapRules.moonBridgeHeight(Map, from)
		local h1 = MapRules.moonBridgeHeight(Map, to)
		local pitch = math.atan2(h1 - h0, step)
		local length = math.sqrt(step * step + (h1 - h0) ^ 2) + 0.2
		local middle = (from + to) / 2
		local surface =
			Vector3.new(bridge.x + ax * middle, GROUND + (h0 + h1) / 2, bridge.z + az * middle)
		local frame = alongFrame(surface, ax, az, pitch)
		local deck = Util.part({
			Name = "Deck",
			Size = Vector3.new(length, bridge.thickness, bridge.width),
			CFrame = frame * CFrame.new(0, -bridge.thickness / 2, 0),
			Color = Util.colour(bridge.colour),
			Material = Enum.Material.Cobblestone,
			Parent = model,
		})
		deck:SetAttribute("RaisedMaxLevel", 6)
		for _, side in { -1, 1 } do
			local offset = Vector3.new(riverX, 0, riverZ) * side * wallOffset
			Util.part({
				Name = "Parapet",
				Size = Vector3.new(length, bridge.parapetHeight, bridge.parapetThickness),
				CFrame = (frame + offset) * CFrame.new(0, bridge.parapetHeight / 2, 0),
				Color = Util.colour(bridge.parapetColour),
				Material = Enum.Material.Slate,
				Parent = model,
			})
		end
	end
end

-- Rope bridge: planks on a gentle sag between four posts, rope rails and
-- hangers. Planks and ropes carry `Sway` so the client can rock them.
local function buildRopeBridge(parent: Instance)
	local bridge = Map.RopeBridge
	local model = Instance.new("Model")
	model.Name = "RopeBridge"
	model.Parent = parent
	local riverX, riverZ, ax, az = riverAxes(bridge.x, bridge.z)
	local across = Vector3.new(riverX, 0, riverZ)
	local along = Vector3.new(ax, 0, az)
	local centre = Vector3.new(bridge.x, GROUND, bridge.z)
	local function at(offset: number, height: number): Vector3
		return centre + along * offset + Vector3.yAxis * height
	end
	local pivot = CFrame.lookAt(at(0, bridge.endHeight), at(0, bridge.endHeight) + along)
	model:SetAttribute("SwayPivot", pivot)
	model:SetAttribute("SwayDegrees", bridge.swayDegrees)
	model:SetAttribute("SwaySeconds", bridge.swaySeconds)

	local plankColour = Util.colour(bridge.plankColour)
	local pitchStep = bridge.plankLength + bridge.plankGap
	local count = math.floor(bridge.length / pitchStep)
	local first = -(count - 1) * pitchStep / 2
	for i = 0, count - 1 do
		local offset = first + i * pitchStep
		local top = MapRules.ropeBridgeHeight(Map, offset)
		local plank = Util.part({
			Name = "Plank",
			Size = Vector3.new(bridge.plankLength, bridge.plankThickness, bridge.width),
			CFrame = alongFrame(at(offset, top - bridge.plankThickness / 2), ax, az, 0),
			Color = plankColour,
			Material = Enum.Material.WoodPlanks,
			Parent = model,
		})
		plank:SetAttribute("RaisedMaxLevel", 6)
		plank:SetAttribute("Sway", true)
	end
	-- Ramps up from each bank.
	for _, direction in { -1, 1 } do
		local ramp = Instance.new("WedgePart")
		ramp.Name = "Ramp"
		ramp.Anchored = true
		ramp.Size = Vector3.new(bridge.width, bridge.endHeight, bridge.rampLength)
		local foot =
			at(direction * (bridge.length / 2 + bridge.rampLength / 2), bridge.endHeight / 2)
		-- A wedge is high at its back (+Z) and low at its front (-Z), so the
		-- front points away from the bridge.
		ramp.CFrame = CFrame.lookAt(foot, foot + along * direction)
		ramp.Color = plankColour
		ramp.Material = Enum.Material.WoodPlanks
		ramp:SetAttribute("RaisedMaxLevel", 6)
		ramp.Parent = model
	end
	-- Posts at the four corners.
	local postColour = Util.colour(bridge.postColour)
	local postOffset = bridge.width / 2 + bridge.postDiameter / 2
	for _, direction in { -1, 1 } do
		for _, side in { -1, 1 } do
			local base = at(direction * bridge.length / 2, bridge.postHeight / 2)
				+ across * side * postOffset
			Util.part({
				Name = "Post",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(bridge.postHeight, bridge.postDiameter, bridge.postDiameter),
				CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)),
				Color = postColour,
				Material = Enum.Material.Wood,
				Parent = model,
			})
		end
	end
	-- Rope rails along each side, following the sag, with hangers down to
	-- the planks.
	local ropeColour = Util.colour(bridge.ropeColour)
	local function rope(a: Vector3, b: Vector3, name: string)
		local length = (b - a).Magnitude
		local part = Util.part({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(length, bridge.ropeThickness, bridge.ropeThickness),
			CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
			Color = ropeColour,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
		part:SetAttribute("Sway", true)
	end
	local pieces = 10
	for _, side in { -1, 1 } do
		local sideOffset = across * side * (bridge.width / 2)
		local previous: Vector3? = nil
		for i = 0, pieces do
			local offset = -bridge.length / 2 + i * bridge.length / pieces
			local deck = at(offset, MapRules.ropeBridgeHeight(Map, offset)) + sideOffset
			local rail = deck + Vector3.yAxis * bridge.ropeHeight
			if previous then
				rope(previous, rail, "Rail")
			end
			if i > 0 and i < pieces then
				rope(deck, rail, "Hanger")
			end
			previous = rail
		end
	end
end

-- Rock ford: rows of flat rocks across the river, touching so plants walk
-- over, plus a few small rocks around it.
local function buildFord(parent: Instance)
	local ford = Map.Ford
	local model = Instance.new("Model")
	model.Name = "Ford"
	model.Parent = parent
	local riverX, riverZ, ax, az = riverAxes(ford.x, ford.z)
	local function rock(x: number, z: number, size: number, top: number, name: string)
		local width = size * (0.85 + Util.random() * 0.3)
		local depth = size * (0.85 + Util.random() * 0.3)
		local height = top + 1
		local tilt = math.rad((Util.random() * 2 - 1) * ford.tiltDegrees)
		local part = Util.part({
			Name = name,
			Size = Vector3.new(width, height, depth),
			CFrame = CFrame.new(x, GROUND + top - height / 2, z)
				* CFrame.Angles(tilt, Util.random() * math.pi * 2, -tilt),
			Color = Util.colour(Util.pick(ford.colours)),
			Material = Enum.Material.Slate,
			Parent = model,
		})
		return part
	end
	for row = 0, ford.rows - 1 do
		local rowOffset = (row - (ford.rows - 1) / 2) * ford.spacing
		for i = 0, ford.rocksAcross - 1 do
			local acrossOffset = (i - (ford.rocksAcross - 1) / 2) * ford.spacing
			local isBank = i == 0 or i == ford.rocksAcross - 1
			local top = if isBank
				then ford.bankTop
				else ford.minTop + Util.random() * (ford.maxTop - ford.minTop)
			local size = ford.minSize + Util.random() * (ford.maxSize - ford.minSize)
			local jitter = ford.spacing * 0.15
			local x = ford.x
				+ ax * acrossOffset
				+ riverX * rowOffset
				+ (Util.random() * 2 - 1) * jitter
			local z = ford.z
				+ az * acrossOffset
				+ riverZ * rowOffset
				+ (Util.random() * 2 - 1) * jitter
			rock(x, z, size, top, "Rock"):SetAttribute("RaisedMaxLevel", 6)
		end
	end
	-- Loose rocks in the water either side.
	for _ = 1, ford.looseRocks do
		local side = if Util.random() < 0.5 then -1 else 1
		local alongRiver = side * (ford.rows * ford.spacing / 2 + 2 + Util.random() * 10)
		local acrossRiver = (Util.random() * 2 - 1) * Map.River.width / 2
		rock(
			ford.x + riverX * alongRiver + ax * acrossRiver,
			ford.z + riverZ * alongRiver + az * acrossRiver,
			ford.looseMinSize + Util.random() * (ford.looseMaxSize - ford.looseMinSize),
			Map.River.depth * (0.6 + Util.random() * 0.6),
			"LooseRock"
		)
	end
end

-- Path of separate pavers from the moon bridge to the gate.
local function buildPath(parent: Instance)
	local path = Map.Path
	local model = Instance.new("Model")
	model.Name = "Path"
	model.Parent = parent
	local step = path.paverSize + path.paverGap
	local perRow = math.floor((path.width + path.paverGap) / step)
	local first = -(perRow - 1) * step / 2
	for _, point in MapRules.pointsAlong(path.centreLine, step, step / 2) do
		local x, z, dx, dz = point[1], point[2], point[3], point[4]
		for i = 0, perRow - 1 do
			local offset = first + i * step
			local jitterA = (Util.random() * 2 - 1) * path.paverJitter
			local jitterB = (Util.random() * 2 - 1) * path.paverJitter
			local px = x - dz * offset + dx * jitterA + dz * jitterB
			local pz = z + dx * offset + dz * jitterA - dx * jitterB
			local turn = math.rad((Util.random() * 2 - 1) * path.paverTurnDegrees)
			local yaw = math.atan2(-dz, dx) + turn
			Util.part({
				Name = "Paver",
				Size = Vector3.new(path.paverSize, path.paverThickness, path.paverSize),
				CFrame = CFrame.new(px, GROUND + path.paverThickness / 2, pz)
					* CFrame.Angles(0, yaw, 0),
				Color = Util.colour(Util.pick(path.colours)),
				Material = Enum.Material.Pavement,
				Parent = model,
			})
		end
	end
end

-- Decorative iron gate in the top wall: cream pillars with lamps, a small
-- side gate and a big double gate with an arched top rail and spear tips.
local function buildGate(parent: Instance)
	local gate = Map.Gate
	local model = Instance.new("Model")
	model.Name = "Gate"
	model.Parent = parent
	local wallZ = -Map.halfSize + gate.pillarSize / 2
	local iron = Util.colour(gate.ironColour)
	local cream = Util.colour(gate.pillarColour)
	local left = gate.x - gate.width / 2
	local pillar = gate.pillarSize
	local bigWidth = gate.width - gate.sideGateWidth - 3 * pillar

	local function block(
		name: string,
		size: Vector3,
		position: Vector3,
		colour: Color3,
		material: Enum.Material
	)
		return Util.part({
			Name = name,
			Size = size,
			Position = position,
			Color = colour,
			Material = material,
			Parent = model,
		})
	end

	local function lamp(x: number)
		local top = GROUND + gate.pillarHeight + 0.6
		block(
			"LampBase",
			Vector3.new(1, 0.4, 1),
			Vector3.new(x, top + 0.2, wallZ),
			iron,
			Enum.Material.Metal
		)
		local glass = block(
			"Lamp",
			Vector3.new(0.9, 1.3, 0.9),
			Vector3.new(x, top + 1.05, wallZ),
			Util.colour(gate.lampColour),
			Enum.Material.Neon
		)
		glass.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = Util.colour(gate.lampColour)
		light.Brightness = gate.lampBrightness
		light.Range = gate.lampRange
		light.Parent = glass
		block(
			"LampCap",
			Vector3.new(1.2, 0.3, 1.2),
			Vector3.new(x, top + 1.85, wallZ),
			iron,
			Enum.Material.Metal
		)
	end

	-- Pillars: left, between the side gate and the big gate, right.
	local pillarXs = {
		left + pillar / 2,
		left + pillar + gate.sideGateWidth + pillar / 2,
		left + gate.width - pillar / 2,
	}
	for _, x in pillarXs do
		block(
			"Pillar",
			Vector3.new(pillar, gate.pillarHeight, pillar),
			Vector3.new(x, GROUND + gate.pillarHeight / 2, wallZ),
			cream,
			Enum.Material.Plaster
		)
		block(
			"PillarCap",
			Vector3.new(pillar + 0.6, 0.6, pillar + 0.6),
			Vector3.new(x, GROUND + gate.pillarHeight + 0.3, wallZ),
			cream,
			Enum.Material.Plaster
		)
		lamp(x)
	end

	-- One iron panel from x0 to x1, with a top rail that arches by `rise`.
	local function panel(x0: number, x1: number, topHeight: number, rise: number)
		local width = x1 - x0
		local function topAt(x: number): number
			local share = (x - (x0 + x1) / 2) / (width / 2)
			return topHeight + rise * (1 - share * share)
		end
		local t = gate.barThickness
		-- Lattice at the bottom, and the bottom and middle rails.
		block(
			"Lattice",
			Vector3.new(width, 1.8, 0.15),
			Vector3.new((x0 + x1) / 2, GROUND + 1.4, wallZ),
			iron,
			Enum.Material.DiamondPlate
		)
		for _, height in { 0.5, 2.3, topHeight - 1.5 } do
			block(
				"Rail",
				Vector3.new(width, t * 1.5, t * 1.5),
				Vector3.new((x0 + x1) / 2, GROUND + height, wallZ),
				iron,
				Enum.Material.Metal
			)
		end
		-- Arched top rail in short pieces.
		local pieces = 8
		for i = 0, pieces - 1 do
			local a = x0 + i * width / pieces
			local b = a + width / pieces
			local ya, yb = GROUND + topAt(a), GROUND + topAt(b)
			local from, to = Vector3.new(a, ya, wallZ), Vector3.new(b, yb, wallZ)
			Util.part({
				Name = "TopRail",
				Size = Vector3.new((to - from).Magnitude + 0.1, t * 1.5, t * 1.5),
				CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0),
				Color = iron,
				Material = Enum.Material.Metal,
				Parent = model,
			})
		end
		-- Upright bars with spear tips above the top rail.
		local count = math.max(1, math.floor(width / gate.barSpacing))
		for i = 0, count do
			local x = x0 + i * width / count
			local height = topAt(x) + 0.8
			block(
				"Bar",
				Vector3.new(t, height, t),
				Vector3.new(x, GROUND + height / 2, wallZ),
				iron,
				Enum.Material.Metal
			)
			Util.part({
				Name = "Spike",
				Size = Vector3.new(0.5, 0.5, 0.2),
				CFrame = CFrame.new(x, GROUND + height + 0.15, wallZ)
					* CFrame.Angles(0, 0, math.rad(45)),
				Color = iron,
				Material = Enum.Material.Metal,
				Parent = model,
			})
		end
	end

	local sideX0 = left + pillar
	panel(sideX0, sideX0 + gate.sideGateWidth, gate.height - 2, 0)
	local bigX0 = sideX0 + gate.sideGateWidth + pillar
	local half = bigWidth / 2
	-- Two leaves meeting at a thicker post, arched like the photo.
	panel(bigX0, bigX0 + half, gate.height - gate.archRise, gate.archRise)
	panel(bigX0 + half, bigX0 + bigWidth, gate.height - gate.archRise, gate.archRise)
	block(
		"MiddlePost",
		Vector3.new(0.8, gate.height, 0.8),
		Vector3.new(bigX0 + half, GROUND + gate.height / 2, wallZ),
		iron,
		Enum.Material.Metal
	)
end

-- Marsh mud: strips that follow the outline, so the marsh has the right
-- shape without one part per stud.
local function buildMarsh(parent: Instance)
	local marsh = Map.Marsh
	local model = Instance.new("Model")
	model.Name = "Marsh"
	model.Parent = parent
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, point in marsh.outline do
		minX, maxX = math.min(minX, point[1]), math.max(maxX, point[1])
		minZ, maxZ = math.min(minZ, point[2]), math.max(maxZ, point[2])
	end
	local row = marsh.stripWidth
	local z = minZ + row / 2
	while z < maxZ do
		local runStart: number? = nil
		local x = minX
		while x <= maxX + 1 do
			local inside = x <= maxX and MapRules.inMarsh(Map, x, z)
			if inside and runStart == nil then
				runStart = x
			elseif not inside and runStart ~= nil then
				Util.part({
					Name = "Mud",
					Size = Vector3.new(x - runStart, 0.2, row),
					Position = Vector3.new((x + runStart) / 2, GROUND + 0.1, z),
					Color = Util.colour(marsh.colour),
					Material = Enum.Material.Mud,
					CanCollide = false,
					CanQuery = false,
					Parent = model,
				})
				runStart = nil
			end
			x += 1
		end
		z += row
	end
	-- Reed clumps with cattails, away from the lily pads.
	local reed = Util.colour(marsh.reedColour)
	local cattail = Util.colour(marsh.cattailColour)
	local placed, tries = 0, 0
	while placed < marsh.reedClumps and tries < marsh.reedClumps * 20 do
		tries += 1
		local cx = minX + Util.random() * (maxX - minX)
		local cz = minZ + Util.random() * (maxZ - minZ)
		local clear = MapRules.inMarsh(Map, cx, cz)
		for _, pad in Map.LilyPads.positions do
			if (pad[1] - cx) ^ 2 + (pad[2] - cz) ^ 2 < (Map.LilyPads.size * 1.5) ^ 2 then
				clear = false
			end
		end
		if clear then
			placed += 1
			for _ = 1, Util.roll(4, 7) do
				local rx = cx + (Util.random() * 2 - 1) * 1.5
				local rz = cz + (Util.random() * 2 - 1) * 1.5
				local height = 3.5 + Util.random() * 3
				local lean = CFrame.Angles(
					math.rad((Util.random() * 2 - 1) * 8),
					0,
					math.rad((Util.random() * 2 - 1) * 8)
				)
				local base = CFrame.new(rx, GROUND, rz) * lean
				Util.part({
					Name = "Reed",
					Size = Vector3.new(0.25, height, 0.25),
					CFrame = base * CFrame.new(0, height / 2, 0),
					Color = reed,
					Material = Enum.Material.Grass,
					CanCollide = false,
					CanQuery = false,
					Parent = model,
				})
				if Util.random() < 0.5 then
					Util.part({
						Name = "Cattail",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(1.3, 0.55, 0.55),
						CFrame = base
							* CFrame.new(0, height - 0.8, 0)
							* CFrame.Angles(0, 0, math.rad(90)),
						Color = cattail,
						Material = Enum.Material.Fabric,
						CanCollide = false,
						CanQuery = false,
						Parent = model,
					})
				end
			end
		end
	end
end

-- One lily pad shape with the classic wedge cut, made once and cloned.
-- Falls back to a plain disc if the cut fails.
local function lilyPadShape(parent: Instance, size: number, colour: Color3): BasePart
	local pads = Map.LilyPads
	local disc = Util.part({
		Parent = parent,
		Name = "LilyPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(pads.thickness, size, size),
		CFrame = CFrame.Angles(0, 0, math.rad(90)),
		Color = colour,
		Material = Enum.Material.SmoothPlastic,
	})
	-- Two flat wedges back to back make the V, with its point at the middle.
	local radial = Vector3.xAxis
	local length = size / 2 + 1
	local spread = length * math.tan(math.rad(pads.notchDegrees / 2))
	local cutters = {}
	for _, side in { 1, -1 } do
		local xVector = Vector3.yAxis * side
		local yVector = Vector3.zAxis * side
		local wedge = Instance.new("WedgePart")
		wedge.Anchored = true
		wedge.Size = Vector3.new(pads.thickness + 1, spread, length)
		wedge.CFrame =
			CFrame.fromMatrix(yVector * spread / 2 + radial * length / 2, xVector, yVector, radial)
		wedge.Parent = parent
		table.insert(cutters, wedge)
	end
	local ok, result = pcall(function()
		return disc:SubtractAsync(cutters)
	end)
	for _, cutter in cutters do
		cutter:Destroy()
	end
	if ok and result then
		disc:Destroy()
		result.Name = "LilyPad"
		result.Anchored = true
		result.UsePartColor = true
		result.Color = colour
		result.Parent = nil
		return result
	end
	disc.Parent = nil
	return disc
end

local function buildLilyPads(parent: Instance)
	local pads = Map.LilyPads
	local model = Instance.new("Model")
	model.Name = "LilyPads"
	model.Parent = parent
	-- The shapes are made at the world origin; their frames there say how to
	-- place a copy at each pad (the cut may change the part's own frame).
	local padShape = lilyPadShape(model, pads.size, Util.colour(pads.colour))
	local rimShape = lilyPadShape(model, pads.size + 0.5, Util.colour(pads.rimColour))
	local padFrame, rimFrame = padShape.CFrame, rimShape.CFrame
	local flower = Util.colour(pads.flowerColour)
	for _, position in pads.positions do
		local scale = 1 + (Util.random() * 2 - 1) * pads.sizeVariation
		local turn = CFrame.Angles(0, Util.random() * math.pi * 2, 0)
		local top = GROUND + pads.thickness + 0.2
		local centre = CFrame.new(position[1], top - pads.thickness / 2, position[2]) * turn

		local rim = rimShape:Clone()
		rim.Name = "LilyPadRim"
		rim.Size *= scale
		rim.CFrame = centre * CFrame.new(0, -0.15, 0) * rimFrame
		rim.CanCollide = false
		rim.CanQuery = false
		rim.Parent = model

		local pad = padShape:Clone()
		pad.Size *= scale
		pad.CFrame = centre * padFrame
		pad:SetAttribute("LilyPad", true)
		pad:SetAttribute("RaisedMaxLevel", 6)
		pad.Parent = model

		if Util.random() < pads.flowerChance then
			local spot = centre * CFrame.new(-pads.size * 0.15, pads.thickness / 2 + 0.3, 0)
			for petal = 0, 4 do
				local angle = petal * math.pi * 2 / 5
				Util.part({
					Name = "Petal",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(0.8, 0.5, 0.8),
					CFrame = spot * CFrame.new(math.cos(angle) * 0.45, 0, math.sin(angle) * 0.45),
					Color = flower,
					Material = Enum.Material.SmoothPlastic,
					CanCollide = false,
					CanQuery = false,
					Parent = model,
				})
			end
			Util.part({
				Name = "FlowerMiddle",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.5,
				CFrame = spot * CFrame.new(0, 0.15, 0),
				Color = Color3.fromRGB(250, 220, 90),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				Parent = model,
			})
		end
	end
	padShape:Destroy()
	rimShape:Destroy()
end

-- Hiding grass: a pale patch covered in tufts of crossed blades, tall enough
-- to hide a level 3 plant. Nothing in it blocks clicks or movement.
local function buildHidingGrass(parent: Instance)
	local grass = Map.HidingGrass
	local model = Instance.new("Model")
	model.Name = "HidingGrass"
	model.Parent = parent
	local colour = Util.colour(grass.colour)
	for _, circle in grass.circles do
		Util.part({
			Name = "GrassPatch",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, circle.radius * 2, circle.radius * 2),
			CFrame = CFrame.new(circle.x, GROUND + 0.1, circle.z)
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = colour,
			Material = Enum.Material.Grass,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
		local spacing = grass.tuftSpacing
		local offset = -circle.radius
		local rowIndex = 0
		while offset <= circle.radius do
			local shift = if rowIndex % 2 == 0 then 0 else spacing / 2
			local along = -circle.radius + shift
			while along <= circle.radius do
				if offset * offset + along * along <= (circle.radius - 2) ^ 2 then
					local height = grass.height * (0.85 + Util.random() * 0.3)
					local shade = 0.85 + Util.random() * 0.25
					local tuftColour = Color3.new(
						math.min(1, colour.R * shade),
						math.min(1, colour.G * shade),
						math.min(1, colour.B * shade)
					)
					local base = CFrame.new(
						circle.x + along,
						GROUND + height / 2,
						circle.z + offset
					) * CFrame.Angles(0, Util.random() * math.pi, 0)
					for _, turn in { 0, 90 } do
						Util.part({
							Name = "Tuft",
							Size = Vector3.new(grass.tuftSize, height, 0.2),
							CFrame = base * CFrame.Angles(0, math.rad(turn), 0),
							Color = tuftColour,
							Material = Enum.Material.Grass,
							CanCollide = false,
							CanQuery = false,
							CastShadow = false,
							Parent = model,
						})
					end
				end
				along += spacing
			end
			offset += spacing * 0.87
			rowIndex += 1
		end
	end
end

-- The River quarter: river, crossings and marsh go in `River` (walkable, so
-- the ground ray sees them); path, gate, grass and reeds go in `RiverDecor`.
local function buildRiverQuarter()
	local wet = Instance.new("Folder")
	wet.Name = "River"
	wet.Parent = folder
	local decor = Instance.new("Folder")
	decor.Name = "RiverDecor"
	decor.Parent = folder
	buildRiver(wet)
	buildMoonBridge(wet)
	buildRopeBridge(wet)
	buildFord(wet)
	buildLilyPads(wet)
	buildMarsh(decor)
	buildPath(decor)
	buildGate(decor)
	buildHidingGrass(decor)
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
	buildRiverQuarter()
	-- The ground ray only looks at walkable ground, not trees or grass.
	rayParams.FilterDescendantsInstances = {
		folder:FindFirstChild("Ground") :: Instance,
		folder:FindFirstChild("Hills") :: Instance,
		folder:FindFirstChild("River") :: Instance,
	}
	buildField()
	buildConservatory()
	buildForest()
	buildGrassland()
end

return MapBuilder
