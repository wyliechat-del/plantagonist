--[[
	Builds the blockout map from Config/Map when the server starts: ground for
	each territory, the conservatory and safe field, the River quarter (river,
	bridges, ford, marsh, lily pads, path, gate, hiding grass), the Hills
	(rises, ramps, tunnels, cave, cliffs, cacti), forest and grassland.
	Mostly plain parts in Workspace.Map, so custom art can replace them later;
	the river water and the Hills ground and rock are terrain.

	Parts with a `RaisedMaxLevel` attribute (bridges, ford rocks, lily pads)
	cancel water and mud slowdown for plants up to that level. Lily pads also
	carry `LilyPad`, which the client uses for the frog hop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Build = require(ReplicatedStorage.Shared.Config.Build)
local HillsShape = require(ReplicatedStorage.Shared.Config.HillsShape)
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
		-- The Hills ground is slate terrain (see buildHills); its part sits
		-- a little lower, as ground under the safe field there.
		local drop = if name == "Hills" then 0.2 else 0
		Util.part({
			Name = name,
			Size = Vector3.new(half, 4, half),
			Position = Vector3.new(
				territory.signX * half / 2,
				GROUND - 2 - drop,
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
	-- The deck swings like a cradle from a line high above it.
	local pivotHeight = bridge.endHeight + bridge.swayPivotHeight
	local pivot = CFrame.lookAt(at(0, pivotHeight), at(0, pivotHeight) + along)
	model:SetAttribute("SwayPivot", pivot)
	model:SetAttribute("SwayDegrees", MapRules.ropeBridgeSwayDegrees(Map))
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
		plank:SetAttribute("SwayBase", plank.CFrame)
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
		part:SetAttribute("SwayBase", part.CFrame)
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
	-- Splashes: white spray off the upstream side of some ford rocks. The
	-- river runs along (riverX, riverZ), so upstream is the other way.
	local upstreamRow = -(ford.rows - 1) / 2 * ford.spacing
	for i = 1, ford.splashRocks do
		local acrossOffset = ((i - 0.5) / ford.splashRocks - 0.5) * Map.River.width
		local spot = Util.part({
			Name = "Splash",
			Size = Vector3.new(1, 1, 1),
			Position = Vector3.new(
				ford.x + ax * acrossOffset + riverX * (upstreamRow - ford.minSize / 2),
				GROUND + Map.River.depth,
				ford.z + az * acrossOffset + riverZ * (upstreamRow - ford.minSize / 2)
			),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = model,
		})
		local spray = Instance.new("ParticleEmitter")
		spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
		spray.Color = ColorSequence.new(Color3.new(1, 1, 1))
		spray.LightEmission = 0.3
		spray.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		spray.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, ford.splashSize * 0.4),
			NumberSequenceKeypoint.new(1, ford.splashSize),
		})
		spray.Rate = ford.splashRate
		spray.Lifetime = NumberRange.new(ford.splashLifetime * 0.6, ford.splashLifetime)
		spray.Speed = NumberRange.new(ford.splashSpeed * 0.6, ford.splashSpeed)
		spray.SpreadAngle = Vector2.new(35, 35)
		spray.Acceleration = Vector3.new(0, -workspace.Gravity * 0.15, 0)
		spray.EmissionDirection = Enum.NormalId.Top
		spray.Parent = spot
	end
	-- Loose rocks in the water either side.
	for _ = 1, ford.looseRocks do
		local side = if Util.random() < 0.5 then -1 else 1
		local alongRiver = side
			* (ford.rows * ford.spacing / 2 + 2 + Util.random() * (ford.looseSpread - 2))
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
				Material = (Enum.Material :: any)[path.paverMaterial],
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
	local bigWidth = gate.width - 2 * gate.sideGateWidth - 4 * pillar

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

	-- Pillars at both ends and either side of the big gate.
	local pillarXs = {
		left + pillar / 2,
		left + pillar + gate.sideGateWidth + pillar / 2,
		left + gate.width - pillar - gate.sideGateWidth - pillar / 2,
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
	local rightX1 = left + gate.width - pillar
	panel(rightX1 - gate.sideGateWidth, rightX1, gate.height - 2, 0)
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

	-- Big padlock on the middle post, facing into the map.
	local lockSize = gate.padlockSize
	local lockX = bigX0 + half
	local lockY = GROUND + gate.padlockHeight
	local lockZ = wallZ + 0.8
	local brass = Util.colour(gate.padlockColour)
	block(
		"Padlock",
		Vector3.new(lockSize, lockSize * 0.85, lockSize * 0.35),
		Vector3.new(lockX, lockY, lockZ),
		brass,
		Enum.Material.Metal
	)
	-- Shackle: two legs and a rounded top.
	local legHeight = lockSize * 0.45
	local legGap = lockSize * 0.32
	for _, side in { -1, 1 } do
		block(
			"Shackle",
			Vector3.new(lockSize * 0.13, legHeight, lockSize * 0.13),
			Vector3.new(lockX + side * legGap, lockY + lockSize * 0.42 + legHeight / 2, lockZ),
			iron,
			Enum.Material.Metal
		)
	end
	Util.part({
		Name = "Shackle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(
			lockSize * 0.13,
			legGap * 2 + lockSize * 0.13,
			legGap * 2 + lockSize * 0.13
		),
		CFrame = CFrame.new(lockX, lockY + lockSize * 0.42 + legHeight, lockZ)
			* CFrame.Angles(0, math.rad(90), 0),
		Color = iron,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	-- Keyhole.
	block(
		"Keyhole",
		Vector3.new(lockSize * 0.12, lockSize * 0.3, 0.1),
		Vector3.new(lockX, lockY - lockSize * 0.1, lockZ + lockSize * 0.18),
		iron,
		Enum.Material.SmoothPlastic
	)
end

-- Loose (dry) stone wall: a dark core with irregular stones on the inner
-- face and along the top.
local function buildStoneWall(parent: Instance)
	local wall = Map.StoneWall
	local model = Instance.new("Model")
	model.Name = "StoneWall"
	model.Parent = parent
	local function stoneColour(): Color3
		return Util.colour(Util.pick(wall.colours))
	end
	for _, run in wall.runs do
		local x0, z0, x1, z1 = run[1], run[2], run[3], run[4]
		local length = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
		local dx, dz = (x1 - x0) / length, (z1 - z0) / length
		-- Inward is towards the map centre.
		local nx, nz = -dz, dx
		local midX, midZ = (x0 + x1) / 2, (z0 + z1) / 2
		if nx * -midX + nz * -midZ < 0 then
			nx, nz = -nx, -nz
		end
		local frame = CFrame.fromMatrix(
			Vector3.new(midX, GROUND, midZ),
			Vector3.new(dx, 0, dz),
			Vector3.yAxis
		)
		local inward = Vector3.new(nx, 0, nz)
		-- Which local Z side faces inward.
		local faceSign = if frame.LookVector:Dot(inward) < 0 then 1 else -1
		Util.part({
			Name = "WallCore",
			Size = Vector3.new(length, wall.height - 0.4, wall.thickness - 0.6),
			CFrame = frame * CFrame.new(0, (wall.height - 0.4) / 2, 0),
			Color = Util.colour(wall.coreColour),
			Material = Enum.Material.Slate,
			Parent = model,
		})
		-- Face stones, course by course.
		local y = 0
		while y < wall.height - 0.6 do
			local course = wall.minStoneHeight
				+ Util.random() * (wall.maxStoneHeight - wall.minStoneHeight)
			course = math.min(course, wall.height - y)
			local along = -length / 2 + Util.random() * wall.minStoneLength * 0.5
			while along < length / 2 do
				local stone = wall.minStoneLength
					+ Util.random() * (wall.maxStoneLength - wall.minStoneLength)
				stone = math.min(stone, length / 2 - along)
				if stone > 0.6 then
					local depthOut = 0.4 + Util.random() * 0.4
					Util.part({
						Name = "Stone",
						Size = Vector3.new(stone - 0.15, course - 0.12, 1.2),
						CFrame = frame * CFrame.new(
							along + stone / 2,
							y + course / 2,
							faceSign * (wall.thickness / 2 - 0.6 + depthOut * 0.5)
						) * CFrame.Angles(
							math.rad((Util.random() * 2 - 1) * 3),
							math.rad((Util.random() * 2 - 1) * 4),
							math.rad((Util.random() * 2 - 1) * 3)
						),
						Color = stoneColour(),
						Material = Enum.Material.Slate,
						Parent = model,
					})
				end
				along += stone
			end
			y += course
		end
		-- Capstones along the top.
		local along = -length / 2
		while along < length / 2 do
			local stone = wall.minStoneLength
				+ Util.random() * (wall.maxStoneLength - wall.minStoneLength)
			stone = math.min(stone, length / 2 - along)
			if stone > 0.6 then
				Util.part({
					Name = "Capstone",
					Size = Vector3.new(stone - 0.1, 0.7, wall.thickness),
					CFrame = frame
						* CFrame.new(along + stone / 2, wall.height - 0.2, 0)
						* CFrame.Angles(
							0,
							math.rad((Util.random() * 2 - 1) * 4),
							math.rad((Util.random() * 2 - 1) * 3)
						),
					Color = stoneColour(),
					Material = Enum.Material.Slate,
					Parent = model,
				})
			end
			along += stone
		end
	end
end

-- Marsh mud: strips that follow the outline, so the marsh has the right
-- shape without one part per stud.
-- One reed standing at (x, z), sometimes with a cattail near its top.
local function reed(parent: Instance, x: number, z: number)
	local marsh = Map.Marsh
	local height = 3.5 + Util.random() * 3
	local lean = CFrame.Angles(
		math.rad((Util.random() * 2 - 1) * 8),
		0,
		math.rad((Util.random() * 2 - 1) * 8)
	)
	local base = CFrame.new(x, GROUND, z) * lean
	Util.part({
		Name = "Reed",
		Size = Vector3.new(0.25, height, 0.25),
		CFrame = base * CFrame.new(0, height / 2, 0),
		Color = Util.colour(marsh.reedColour),
		Material = Enum.Material.Grass,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	if Util.random() < 0.5 then
		Util.part({
			Name = "Cattail",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.3, 0.55, 0.55),
			CFrame = base * CFrame.new(0, height - 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Util.colour(marsh.cattailColour),
			Material = Enum.Material.Fabric,
			CanCollide = false,
			CanQuery = false,
			Parent = parent,
		})
	end
end

-- A clump of 4 to 7 reeds round (x, z), or `count` reeds if it isn't 0.
local function reedClump(parent: Instance, x: number, z: number, count: number)
	if count == 1 then
		reed(parent, x, z)
		return
	end
	for _ = 1, if count > 0 then count else Util.roll(4, 7) do
		reed(parent, x + (Util.random() * 2 - 1) * 1.5, z + (Util.random() * 2 - 1) * 1.5)
	end
end

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
			reedClump(model, cx, cz, 0)
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

-- A white water lily (decoration only): two rings of pointed petals
-- opening upwards round a yellow middle. `base` is the pad's top surface.
local function waterLily(parent: Instance, base: CFrame)
	local pads = Map.LilyPads
	local white = Util.colour(pads.petalColour)
	local tip = Util.colour(pads.petalTipColour)
	local spot = base * CFrame.Angles(0, Util.random() * math.pi * 2, 0)
	local rings = {
		{ count = 8, length = 1.5, width = 0.6, lean = 30, turn = 0, colour = tip },
		{ count = 8, length = 1.2, width = 0.5, lean = 55, turn = 22.5, colour = white },
	}
	for _, ring in rings do
		for i = 0, ring.count - 1 do
			local angle = math.rad(i * 360 / ring.count + ring.turn)
			-- Each petal starts at the middle, points outwards and leans up.
			local petalFrame = spot
				* CFrame.Angles(0, angle, 0)
				* CFrame.Angles(0, 0, math.rad(ring.lean))
				* CFrame.new(ring.length / 2, 0.1, 0)
			local petal = Util.part({
				Name = "Petal",
				Size = Vector3.new(ring.length, 0.12, ring.width),
				CFrame = petalFrame,
				Color = ring.colour,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Parent = parent,
			})
			-- Pointed tip: a small turned square at the outer end.
			Util.part({
				Name = "PetalTip",
				Size = Vector3.new(ring.width * 0.7, 0.12, ring.width * 0.7),
				CFrame = petal.CFrame
					* CFrame.new(ring.length / 2, 0, 0)
					* CFrame.Angles(0, math.rad(45), 0),
				Color = ring.colour,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Parent = parent,
			})
		end
	end
	Util.part({
		Name = "LilyMiddle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 0.8, 0.8),
		CFrame = spot * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Util.colour(pads.flowerCentreColour),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
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
	local layout = MapRules.lilyPadLayout(Map)
	for index, position in layout do
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

		-- White water lilies by the first pads (the guide positions), on the
		-- water beside the pad.
		if index <= pads.lilyFlowers then
			local x, z = MapRules.lilyFlowerSpot(Map, layout, index, pads.size / 2 * scale)
			waterLily(model, CFrame.new(x, GROUND + 0.2, z))
		end
	end
	padShape:Destroy()
	rimShape:Destroy()
end

-- One grass blade standing at (x, z): a thin stretched ellipsoid, part
-- sunk into the ground, turned any way, sized and coloured at random. It
-- keeps its base in a `BladeBase` attribute so clients can wave it.
local function grassBlade(parent: Instance, x: number, z: number, scale: number?)
	local grass = Map.HidingGrass
	local length = grass.height
		* Util.between(grass.sizeRange[1], grass.sizeRange[2])
		* (scale or 1)
	local base = CFrame.new(x, GROUND, z) * CFrame.Angles(0, Util.random() * math.pi * 2, 0)
	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Anchored = true
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CanTouch = false
	blade.CastShadow = false
	blade.Material = Enum.Material.SmoothPlastic
	blade.Color = Util.colour(Util.pick(grass.bladeColours))
	blade.Size = Vector3.new(grass.bladeThickness, length, length * grass.bladeWidth)
	blade.CFrame = base * CFrame.new(0, length * (0.5 - grass.bladeSunk), 0)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = blade
	blade:SetAttribute("BladeBase", base)
	blade.Parent = parent
end

-- Hiding grass: a pale patch covered in single grass blades, tall enough
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
		local spacing = grass.bladeSpacing
		local offset = -circle.radius
		local rowIndex = 0
		while offset <= circle.radius do
			local shift = if rowIndex % 2 == 0 then 0 else spacing / 2
			local along = -circle.radius + shift
			while along <= circle.radius do
				if offset * offset + along * along <= (circle.radius - 2) ^ 2 then
					local spread = grass.bladeSpread
					grassBlade(
						model,
						circle.x + along + Util.between(-spread, spread),
						circle.z + offset + Util.between(-spread, spread)
					)
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
-- Grass terrain over the River quarter's ground, in rows of 4 stud cells
-- (the terrain cell size). None next to the safe field (it has its own
-- grass) or under the path (terrain grass blades would poke through).
-- Terrain grass (Map.River's ground material and colour) over one
-- quarter's ground, `signX`, `signZ` saying which, on each cell where
-- `grassy(x, z)` says so, and never in the safe field.
local function grassGround(signX: number, signZ: number, grassy: (number, number) -> boolean)
	local river = Map.River
	local terrain = workspace.Terrain
	local material = (Enum.Material :: any)[river.groundMaterial]
	terrain:SetMaterialColor(material, Util.colour(river.groundColour))
	local cell = Map.Hills.terrainCell
	local count = math.ceil(Map.halfSize / cell)
	local fieldClear = Map.Field.radius + cell
	for j = 1, count do
		local z = signZ * (j - 0.5) * cell
		local start = nil
		for i = 1, count + 1 do
			local x = signX * (i - 0.5) * cell
			local fill = i <= count and x * x + z * z > fieldClear * fieldClear and grassy(x, z)
			if fill and start == nil then
				start = i
			elseif not fill and start ~= nil then
				local x0, x1 = signX * (start - 1) * cell, signX * (i - 1) * cell
				terrain:FillBlock(
					CFrame.new((x0 + x1) / 2, GROUND - cell / 2, z),
					Vector3.new(math.abs(x0 - x1), cell, cell),
					material
				)
				start = nil
			end
		end
	end
end

-- The River quarter's ground away from the marsh: terrain grass, except
-- under the path and near the river, marsh and hiding grass.
local function riverGround()
	grassGround(-1, -1, function(x, z)
		return not MapRules.onPath(Map, x, z) and not MapRules.keepGrassGroundOff(Map, x, z)
	end)
end

-- Reed clumps and single reeds along both river banks.
local function buildRiverReeds(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "RiverReeds"
	model.Parent = parent
	for _, spot in MapRules.riverReedSpots(Map) do
		reedClump(model, spot[1], spot[2], spot[3])
	end
end

-- One gaslight with its base at (x, z): a black iron post with a fluted
-- base and a crossbar, and a glass lantern with a glowing flame inside.
-- With `postHeight` it is a lamp for a pillar top instead: just a short
-- iron post and the lantern, standing on height `floor`.
local function pathLight(
	parent: Instance,
	x: number,
	z: number,
	floor: number?,
	postHeight: number?
)
	local lights = Map.PathLights
	local y0 = GROUND + (floor or 0)
	local iron = Util.colour(lights.ironColour)
	local model = Instance.new("Model")
	model.Name = "PathLight"
	model.Parent = parent
	local function piece(name: string, size: Vector3, y: number, props: { [string]: any }?)
		local part = Util.part({
			Name = name,
			Size = size,
			CFrame = CFrame.new(x, y0 + y, z),
			Color = iron,
			Material = Enum.Material.Metal,
			Parent = model,
		})
		for key, value in props or {} do
			(part :: any)[key] = value
		end
		return part
	end
	local function upright(name: string, diameter: number, height: number, y: number)
		local part = piece(name, Vector3.new(height, diameter, diameter), y + height / 2)
		part.Shape = Enum.PartType.Cylinder
		part.CFrame = CFrame.new(x, y0 + y + height / 2, z) * CFrame.Angles(0, 0, math.rad(90))
		return part
	end
	local base, post = lights.baseDiameter, lights.postDiameter
	local bottom = lights.lanternBottom
	if postHeight then
		bottom = postHeight
		upright("Post", post, bottom, 0)
	else
		upright("Foot", base * 1.15, 0.4, 0)
		upright("Base", base, lights.baseHeight, 0.4)
		upright("BaseRing", base * 1.1, 0.3, 0.4 + lights.baseHeight)
		local postBottom = 0.7 + lights.baseHeight
		upright("Post", post, bottom - postBottom, postBottom)
		upright("Collar", post * 1.5, 0.3, lights.crossbarHeight - 0.8)
		piece("Crossbar", Vector3.new(lights.crossbarLength, 0.2, 0.2), lights.crossbarHeight)
	end
	local top = bottom + lights.height - lights.lanternBottom
	-- Lantern: a tray, glass sides with black corner posts, and a roof.
	local size, tall = lights.lanternSize, lights.lanternHeight
	piece("LanternTray", Vector3.new(size * 0.8, 0.25, size * 0.8), bottom + 0.125)
	piece("Glass", Vector3.new(size, tall, size), bottom + 0.25 + tall / 2, {
		Color = Util.colour(lights.glassColour),
		Material = Enum.Material.Glass,
		Transparency = lights.glassTransparency,
		CanCollide = false,
	})
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local part = piece("LanternFrame", Vector3.new(0.12, tall, 0.12), bottom + 0.25 + tall / 2)
		part.CFrame = CFrame.new(
			x + corner[1] * size / 2,
			y0 + bottom + 0.25 + tall / 2,
			z + corner[2] * size / 2
		)
	end
	local flame = piece("Flame", Vector3.new(0.5, 0.7, 0.5), bottom + 0.25 + tall * 0.45, {
		Color = Util.colour(lights.flameColour),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Color = Util.colour(lights.flameColour)
	light.Brightness = lights.lightBrightness
	light.Range = lights.lightRange
	light.Shadows = false
	light.Parent = flame
	local roofY = bottom + 0.25 + tall
	piece("Roof", Vector3.new(size * 1.3, 0.25, size * 1.3), roofY + 0.125)
	piece("RoofTop", Vector3.new(size * 0.8, 0.35, size * 0.8), roofY + 0.425)
	local finial = top - (roofY + 0.6)
	upright("FinialStem", 0.2, finial * 0.6, roofY + 0.6)
	local ball = piece("Finial", Vector3.new(0.4, 0.4, 0.4), top - 0.2)
	ball.Shape = Enum.PartType.Ball
end

-- Four short stone towers at the moon bridge's ends, one either side of
-- the deck, each with a gas lamp on top (build 15B).
local function buildBridgeTowers(parent: Instance)
	local bridge = Map.MoonBridge
	local towers = bridge.towers
	local model = Instance.new("Model")
	model.Name = "BridgeTowers"
	model.Parent = parent
	local riverX, riverZ, ax, az = riverAxes(bridge.x, bridge.z)
	local along = bridge.span / 2 - towers.size / 2
	local across = bridge.width / 2 + towers.size / 2
	for _, endSide in { -1, 1 } do
		for _, side in { -1, 1 } do
			local x = bridge.x + ax * along * endSide + riverX * across * side
			local z = bridge.z + az * along * endSide + riverZ * across * side
			local middle = Vector3.new(x, GROUND + towers.height / 2, z)
			Util.part({
				Name = "BridgeTower",
				Size = Vector3.new(towers.size, towers.height, towers.size),
				CFrame = CFrame.lookAt(middle, middle + Vector3.new(ax, 0, az)),
				Color = Util.colour(bridge.parapetColour),
				Material = Enum.Material.Slate,
				Parent = model,
			})
			pathLight(model, x, z, towers.height, towers.lampPost)
		end
	end
end

local function buildPathLights(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "PathLights"
	model.Parent = parent
	for _, spot in MapRules.pathLightSpots(Map) do
		pathLight(model, spot[1], spot[2])
	end
end

local function buildRiverQuarter()
	local wet = Instance.new("Folder")
	wet.Name = "River"
	wet.Parent = folder
	local decor = Instance.new("Folder")
	decor.Name = "RiverDecor"
	decor.Parent = folder
	riverGround()
	buildRiver(wet)
	buildMoonBridge(wet)
	buildBridgeTowers(wet)
	buildRopeBridge(wet)
	buildFord(wet)
	buildLilyPads(wet)
	buildMarsh(decor)
	buildPath(decor)
	buildPathLights(decor)
	buildRiverReeds(decor)
	buildGate(decor)
	buildStoneWall(decor)
	buildHidingGrass(decor)
end

-- Hills quarter ------------------------------------------------------------
-- Terrain for the slate ground and the rock of the rises, from the traced
-- outlines in Config/HillsShape; parts for the arched tunnel roofs, the
-- leaning cliff slabs, ramps, the bottom left hill and the edge cliff wall.

local RISE_MATERIALS = { Enum.Material.Sandstone, Enum.Material.Rock, Enum.Material.Basalt }

local function variedColour(rgb: { number }, amount: number): Color3
	local shift = (Util.random() * 2 - 1) * amount
	return Color3.fromRGB(
		math.clamp(rgb[1] + shift, 0, 255),
		math.clamp(rgb[2] + shift, 0, 255),
		math.clamp(rgb[3] + shift, 0, 255)
	)
end

local function inHillsQuarter(x: number, z: number): boolean
	local limit = Map.halfSize - 1
	return x > 1 and x < limit and z < -1 and z > -limit and not MapRules.inField(Map, x, z)
end

local function hasRock(entry: { number }): boolean
	return entry[2] > 0
end

-- A ray onto the built Hills, for setting things on the real surface. It
-- hits everything except the Hills decor (set by buildHills). An Include
-- list with the terrain in it missed the terrain in Studio (build 11), so
-- this leaves things out instead.
local surfaceParams = RaycastParams.new()
surfaceParams.FilterType = Enum.RaycastFilterType.Exclude
surfaceParams.IgnoreWater = true
local surfaceMisses = 0

-- Height of the surface at (x, z), from above.
local function surfaceY(x: number, z: number): number
	local result =
		workspace:Raycast(Vector3.new(x, GROUND + 200, z), Vector3.new(0, -400, 0), surfaceParams)
	if result == nil then
		surfaceMisses += 1
		return GROUND
	end
	return result.Position.Y
end

-- Calls `fill(i0, i1, j, value)` for each run of cells in a row that share
-- the same non-nil `valueAt(i, j)` (compared with `key`).
local function rowRuns(
	count: number,
	valueAt: (i: number, j: number) -> any,
	fill: (i0: number, i1: number, j: number, value: any) -> ()
)
	for j = 1, count do
		local start, current = nil, nil
		for i = 1, count + 1 do
			local value = if i <= count then valueAt(i, j) else nil
			if value ~= current then
				if current ~= nil then
					fill(start :: number, i - 1, j, current)
				end
				start, current = i, value
			end
		end
	end
end

-- Slate ground (not under the safe field), grass patches, and sand round
-- the foot of the cliffs.
local function hillsGround(terrain: Terrain, grid: { { { number } } })
	local hills = Map.Hills
	local cell = hills.terrainCell
	local count = #grid
	terrain:SetMaterialColor(Enum.Material.Slate, Util.colour(hills.groundColour))
	terrain:SetMaterialColor(Enum.Material.Sand, Util.colour(hills.sandColour))
	terrain:SetMaterialColor(Enum.Material.Grass, Util.colour(hills.grassColour))
	local function middle(i: number, j: number): (number, number)
		return (i - 0.5) * cell, -(j - 0.5) * cell
	end
	local function fillRun(i0: number, i1: number, j: number, material: Enum.Material)
		local x0, x1 = (i0 - 1) * cell, i1 * cell
		terrain:FillBlock(
			CFrame.new((x0 + x1) / 2, GROUND - cell / 2, -(j - 0.5) * cell),
			Vector3.new(x1 - x0, cell, cell),
			material
		)
	end
	-- The safe field keeps its grass: no terrain where a cell's middle is
	-- inside it.
	rowRuns(count, function(i, j)
		local x, z = middle(i, j)
		return if MapRules.inField(Map, x, z) then nil else Enum.Material.Slate
	end, fillRun)
	-- Is any point within `reach` of (x, z) in a tunnel or on the bottom
	-- left hill? (Neither is in the rock grid, so check them by shape.)
	local function nearTunnel(x: number, z: number, reach: number): boolean
		local step = cell / 2
		for dx = -reach, reach, step do
			for dz = -reach, reach, step do
				if dx * dx + dz * dz <= reach * reach then
					local px, pz = x + dx, z + dz
					if
						MapRules.inTunnel(Map, HillsShape, px, pz)
						or MapRules.onFirstHill(Map, HillsShape, px, pz)
					then
						return true
					end
				end
			end
		end
		return false
	end
	for _ = 1, hills.grassPatches do
		local x, z = MapRules.randomPointIn(Map, "Hills", Util.random)
		local radius = Util.roll(hills.patchMinRadius, hills.patchMaxRadius)
		-- Only on open ground: not under or next to rock, and clear of the
		-- cave, the tunnels and the bottom left hill.
		local clear = radius + cell
		if
			MapRules.distanceFromCentre(x, z) > Map.Field.radius + radius
			and MapRules.distanceToCells(Map, grid, x, z, clear, hasRock, false) >= clear
			and not nearTunnel(x, z, clear)
		then
			terrain:FillCylinder(
				CFrame.new(x, GROUND - cell / 2, z),
				cell,
				radius,
				Enum.Material.Grass
			)
		end
	end
	-- Cells under the bottom left hill's ramps, so they get sand round
	-- them like the foot of a cliff.
	local hillRamps: { { { number } } } = {}
	for j = 1, count do
		hillRamps[j] = {}
		for i = 1, count do
			local x, z = middle(i, j)
			local onRamp = false
			for _, section in MapRules.rampSections(Map, HillsShape) do
				if section.firstHill == 1 then
					local rx, rz = x - section.x, z - section.z
					local along = rx * section.ax + rz * section.az
					local across = -rx * section.az + rz * section.ax
					if
						math.abs(along) <= section.length / 2
						and math.abs(across) <= section.width / 2
					then
						onRamp = true
					end
				end
			end
			hillRamps[j][i] = { if onRamp then 1 else 0 }
		end
	end
	local function isHillRamp(entry: { number }): boolean
		return entry[1] > 0
	end
	rowRuns(count, function(i, j)
		local x, z = middle(i, j)
		if
			hasRock(grid[j][i])
			or MapRules.inField(Map, x, z)
			or MapRules.rampAt(Map, HillsShape, x, z) ~= nil
			or MapRules.onFirstHill(Map, HillsShape, x, z)
		then
			return nil
		end
		local reach = hills.cliffSandMaxWidth + 1
		local distance = math.min(
			MapRules.distanceToCells(Map, grid, x, z, reach, hasRock, false),
			MapRules.distanceToCells(Map, hillRamps, x, z, reach, isHillRamp, false)
		)
		return if distance <= MapRules.cliffSandWidth(Map, x, z) then Enum.Material.Sand else nil
	end, fillRun)
end

-- The rock of the rises, filled in terrain cells (merged into rectangles
-- of the same shape).
local function hillsRock(terrain: Terrain, grid: { { { number } } })
	local hills = Map.Hills
	local cell = hills.terrainCell
	for layer, material in RISE_MATERIALS do
		terrain:SetMaterialColor(material, Util.colour(hills.riseColours[layer]))
	end
	type Rect = { i0: number, i1: number, j0: number, j1: number, entry: { number } }
	local finished: { Rect } = {}
	local open: { [string]: Rect } = {}
	local rowJ = 0
	local row: { [string]: Rect } = {}
	local function closeRow()
		local nextOpen = {}
		for key, rect in row do
			local above = open[key]
			if above then
				above.j1 = rect.j1
				nextOpen[key] = above
				open[key] = nil
			else
				nextOpen[key] = rect
			end
		end
		for _, rect in open do
			table.insert(finished, rect)
		end
		open, row = nextOpen, {}
	end
	rowRuns(#grid, function(i, j)
		local entry = grid[j][i]
		return if entry[2] > entry[1] then `{entry[1]}:{entry[2]}:{entry[3]}` else nil
	end, function(i0, i1, j, key)
		if j ~= rowJ then
			closeRow()
			-- A row with no rock between ends every rectangle.
			if j > rowJ + 1 then
				closeRow()
			end
			rowJ = j
		end
		row[`{i0}:{i1}:{key}`] = { i0 = i0, i1 = i1, j0 = j, j1 = j, entry = grid[j][i0] }
	end)
	closeRow()
	closeRow()
	for _, rect in open do
		table.insert(finished, rect)
	end
	for _, rect in finished do
		local bottom, top, layer = rect.entry[1], rect.entry[2], rect.entry[3]
		local x0, x1 = (rect.i0 - 1) * cell, rect.i1 * cell
		local z0, z1 = -(rect.j1 * cell), -((rect.j0 - 1) * cell)
		local function fill(to: number, material: Enum.Material)
			terrain:FillBlock(
				CFrame.new((x0 + x1) / 2, GROUND + (bottom + to) / 2, (z0 + z1) / 2),
				Vector3.new(x1 - x0, to - bottom, z1 - z0),
				material
			)
		end
		-- The whole column in the top rise's rock, then the lower rises'
		-- rock over it, so cliff faces show the layers. Each fill runs
		-- from the bottom, as terrain keeps the fuller of two fills.
		fill(top, RISE_MATERIALS[layer])
		local x, z = (x0 + x1) / 2, (z0 + z1) / 2
		for lower = layer - 1, 1, -1 do
			local height = MapRules.riseHeight(Map, lower, x, z)
			if height > bottom then
				fill(height, RISE_MATERIALS[lower])
			end
		end
	end
end

-- Arched roofs over the tunnels and the cave: squares of `archStep`
-- studs, each from the arch height (lower near a wall) up to the rock.
local function hillsArches(parent: Instance, grid: { { { number } } })
	local hills = Map.Hills
	local cell, step = hills.terrainCell, hills.archStep
	local per = cell // step
	local colour = Util.colour(hills.riseColours[1])
	local count = #grid
	-- Arch height for each small square, row by row.
	local rows = per * count
	local function heightAt(si: number, sj: number): { number }?
		local i, j = (si - 1) // per + 1, (sj - 1) // per + 1
		local entry = grid[j][i]
		if entry[1] == 0 then
			return nil
		end
		local x, z = (si - 0.5) * step, -(sj - 0.5) * step
		local cave = entry[1] == hills.caveRockBottom
		local wall = if cave then hills.caveWallHeight else hills.tunnelWallHeight
		local clearance = if cave then hills.caveClearance else hills.tunnelClearance
		local reach = if cave then hills.caveArchReach else hills.tunnelArchReach
		local distance = MapRules.distanceToCells(Map, grid, x, z, reach, MapRules.isWallCell, true)
		local arch = MapRules.archHeight(wall, clearance, reach, distance)
		return { math.floor(arch * 4 + 0.5) / 4, entry[1] }
	end
	local cache: { [number]: { [number]: { number }? } } = {}
	rowRuns(rows, function(si, sj)
		cache[sj] = cache[sj] or {}
		local value = heightAt(si, sj)
		cache[sj][si] = value
		return if value then `{value[1]}:{value[2]}` else nil
	end, function(i0, i1, sj)
		local value = cache[sj][i0] :: { number }
		local arch, top = value[1], value[2]
		local x0, x1 = (i0 - 1) * step, i1 * step
		Util.part({
			Name = "TunnelRoof",
			Size = Vector3.new(x1 - x0, top - arch, step),
			Position = Vector3.new((x0 + x1) / 2, GROUND + (arch + top) / 2, -(sj - 0.5) * step),
			Color = colour,
			Material = Enum.Material.Sandstone,
			Parent = parent,
		})
	end)
end

-- Leaning rock slabs along the cliff edges of each rise. None in front of
-- tunnels, ramps or the bottom left hill, or along the map edge.
local function hillsSlabs(parent: Instance)
	local hills = Map.Hills
	local function blocked(x: number, z: number): boolean
		return not inHillsQuarter(x, z)
			or MapRules.inTunnel(Map, HillsShape, x, z)
			or MapRules.rampAt(Map, HillsShape, x, z) ~= nil
	end
	-- Each rise's outlines, and the bottom left hill (a First Rise hill).
	local edges: { { layer: number, outline: { { number } } } } = {}
	for layer, outlines in HillsShape.rises do
		for _, outline in outlines do
			table.insert(edges, { layer = layer, outline = outline })
		end
	end
	table.insert(edges, { layer = 1, outline = hills.firstHill.outline })
	for _, edge in edges do
		local layer, outline = edge.layer, edge.outline
		for k = 1, #outline do
			local a, b = outline[k], outline[k % #outline + 1]
			local ex, ez = b[1] - a[1], b[2] - a[2]
			local length = math.sqrt(ex * ex + ez * ez)
			local count = math.floor(length / hills.slabSpacing)
			if count > 0 then
				ex, ez = ex / length, ez / length
				for n = 0, count - 1 do
					local share = (n + 0.5) / count
					local x, z = a[1] + ex * length * share, a[2] + ez * length * share
					-- Outward is the side that isn't this rise.
					local ox, oz = -ez, ex
					if MapRules.inPolygon(outline, x + ox * 2, z + oz * 2) then
						ox, oz = -ox, -oz
					end
					local width = Util.roll(hills.slabMinWidth, hills.slabMaxWidth)
					local thickness = Util.roll(hills.slabMinThickness, hills.slabMaxThickness)
					local half = width / 2
					if
						not blocked(x, z)
						and not blocked(x + ex * half, z + ez * half)
						and not blocked(x - ex * half, z - ez * half)
						and not blocked(x + ox * 4, z + oz * 4)
					then
						local base = if layer > 1
							then MapRules.riseHeight(Map, layer - 1, x, z)
							else 0
						local slabTop = MapRules.riseHeight(Map, layer, x, z) - Util.roll(0.2, 1)
						local bottom = base - 1
						local height = slabTop - bottom
						local centre = Vector3.new(
							x + ox * thickness * 0.25,
							GROUND + bottom + height / 2,
							z + oz * thickness * 0.25
						)
						local frame = CFrame.lookAt(centre, centre + Vector3.new(ox, 0, oz))
							* CFrame.Angles(
								0,
								math.rad(Util.roll(-1, 1) * hills.slabMaxTurnDegrees),
								0
							)
							* CFrame.Angles(
								math.rad(Util.roll(-1, 1) * hills.slabMaxTiltDegrees),
								0,
								0
							)
						Util.part({
							Name = "CliffSlab",
							Size = Vector3.new(width, height, thickness),
							CFrame = frame,
							Color = variedColour(
								hills.riseColours[layer],
								hills.slabColourVariation
							),
							Material = Enum.Material.Slate,
							Parent = parent,
						})
					end
				end
			end
		end
	end
end

-- A boulder of Second Rise rock sitting on whatever is under it.
local function boulder(parent: Instance, x: number, z: number, maxSize: number)
	local hills = Map.Hills
	local size = Util.roll(hills.boulderMinSize, maxSize)
	-- None in or at the edge of the river (they looked like they floated
	-- on the water).
	for _, offset in { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		if MapRules.inRiver(Map, x + offset[1] * size, z + offset[2] * size) then
			return
		end
	end
	local dimensions =
		Vector3.new(size, size * Util.between(0.55, 0.9), size * Util.between(0.7, 1.2))
	local base = surfaceY(x, z)
	Util.part({
		Name = "Boulder",
		Size = dimensions,
		CFrame = CFrame.new(x, base + dimensions.Y * 0.3, z) * CFrame.Angles(
			math.rad(Util.roll(-15, 15)),
			Util.random() * math.pi * 2,
			math.rad(Util.roll(-15, 15))
		),
		Color = variedColour(hills.riseColours[2], hills.slabColourVariation),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
end

-- Ramps up to the First Rise, in pieces turned a little from each other
-- (like fallen rock), with a landing at the top. Boulders come later
-- (hillsBoulders), once there is a surface to set them on.
local function hillsRamps(parent: Instance)
	local hills = Map.Hills
	local colour = Util.colour(hills.riseColours[1])
	local sections = MapRules.rampSections(Map, HillsShape)
	local function block(name: string, size: Vector3, frame: CFrame)
		Util.part({
			Name = name,
			Size = size,
			CFrame = frame,
			Color = colour,
			Material = Enum.Material.Sandstone,
			Parent = parent,
		})
	end
	for index, section in sections do
		local uphill = Vector3.new(section.ax, 0, section.az)
		local centre = Vector3.new(section.x, GROUND, section.z)
		local facing = CFrame.lookAt(centre, centre + uphill)
		if section.low > 0 then
			block(
				"RampBase",
				Vector3.new(section.width, section.low, section.length),
				facing * CFrame.new(0, section.low / 2, 0)
			)
		end
		local rise = section.high - section.low
		if rise > 0 then
			local middle = centre + Vector3.new(0, section.low + rise / 2, 0)
			local wedge = Instance.new("WedgePart")
			wedge.Name = "Ramp"
			wedge.Anchored = true
			wedge.Size = Vector3.new(section.width, rise, section.length)
			-- A wedge is high at its back and low at its front.
			wedge.CFrame = CFrame.lookAt(middle, middle - uphill)
			wedge.Color = colour
			wedge.Material = Enum.Material.Sandstone
			wedge.Parent = parent
		end
		-- The bottom left hill's ramps: ragged broken pieces sticking out
		-- of the low end.
		if section.firstHill == 1 and section.low == 0 then
			local toe = hills.firstHill
			local foot = centre - uphill * (section.length / 2)
			local acrossVector = Vector3.new(-section.az, 0, section.ax)
			for n = 1, toe.toePieces do
				local share = (n - 0.5) / toe.toePieces - 0.5
				local length = Util.roll(toe.toeLength[1], toe.toeLength[2])
				local turn = math.rad(Util.roll(-1, 1) * toe.toeTurnDegrees)
				local outward = CFrame.Angles(0, turn, 0):VectorToWorldSpace(-uphill)
				local start = foot + acrossVector * section.width * share
				local middle = start
					+ outward * (length / 2 - 0.5)
					+ Vector3.new(0, toe.toeHeight / 2, 0)
				local piece = Instance.new("WedgePart")
				piece.Name = "RampToe"
				piece.Anchored = true
				piece.Size = Vector3.new(
					section.width / toe.toePieces * Util.roll(0.7, 1.2),
					toe.toeHeight,
					length
				)
				piece.CFrame = CFrame.lookAt(middle, middle + outward)
				piece.Color = variedColour(hills.riseColours[1], 6)
				piece.Material = Enum.Material.Sandstone
				piece.Parent = parent
			end
		end
		-- The last piece of each ramp: a landing past the top covers any
		-- gap to the rise.
		if index % 3 == 0 then
			local top = centre + uphill * (section.length / 2 + hills.terrainCell / 2 - 0.5)
			block(
				"RampTop",
				Vector3.new(section.width, section.high, hills.terrainCell),
				CFrame.lookAt(top, top + uphill) * CFrame.new(0, section.high / 2, 0)
			)
		end
	end
end

-- The tunnel through the bottom left hill: side walls and a flat roof
-- with an arched underside, as parts. The rest of the hill is terrain
-- rock (hillsRock), meeting the outside of the walls.
local function hillsRidge(parent: Instance)
	local hills = Map.Hills
	local ridge = HillsShape.ridge
	local colour = Util.colour(hills.riseColours[1])
	local centre = Vector3.new(ridge.x, GROUND, ridge.z)
	local along = Vector3.new(ridge.dx, 0, ridge.dz)
	-- Local X runs across the hill, Z along it.
	local frame = CFrame.lookAt(centre, centre + along)
	local height, clearance = hills.riseHeights[1], hills.tunnelClearance
	local tunnel, wall = hills.ridgeTunnelWidth, hills.ridgeWallWidth
	local band = MapRules.ridgeBandHalf(Map) * 2
	local function block(name: string, size: Vector3, offset: Vector3)
		Util.part({
			Name = name,
			Size = size,
			CFrame = frame * CFrame.new(offset),
			Color = colour,
			Material = Enum.Material.Sandstone,
			Parent = parent,
		})
	end
	block(
		"HillTop",
		Vector3.new(band, height - clearance, ridge.length),
		Vector3.new(0, clearance + (height - clearance) / 2, 0)
	)
	-- The arch: strips along the tunnel, lower near the walls.
	local strip = 1
	local across = -tunnel / 2
	while across < tunnel / 2 - 0.01 do
		local middle = across + strip / 2
		local fromWall = tunnel / 2 - math.abs(middle) - strip / 2
		local arch =
			MapRules.archHeight(hills.tunnelWallHeight, clearance, hills.tunnelArchReach, fromWall)
		if arch < clearance - 0.05 then
			block(
				"TunnelRoof",
				Vector3.new(strip, clearance - arch, ridge.length),
				Vector3.new(middle, (arch + clearance) / 2, 0)
			)
		end
		across += strip
	end
	for _, side in { -1, 1 } do
		block(
			"TunnelWall",
			Vector3.new(wall, clearance, ridge.length),
			Vector3.new(side * (tunnel / 2 + wall / 2), clearance / 2, 0)
		)
	end
end

-- A miner's lantern on a bracket, on a wall at (x, z) facing (nx, nz),
-- hanging at `y` (world height).
local function wallLantern(
	parent: Instance,
	x: number,
	z: number,
	nx: number,
	nz: number,
	y: number
)
	local hills = Map.Hills
	local size = hills.lanternSize
	local frameColour = Util.colour(hills.lanternFrameColour)
	local model = Instance.new("Model")
	model.Name = "Lantern"
	model.Parent = parent
	local out = Vector3.new(nx, 0, nz)
	local wallPoint = Vector3.new(x, y, z)
	local reach = size * 0.5 + 0.6 + hills.lanternWallGap
	local hang = wallPoint + out * reach
	local function piece(
		name: string,
		sizeOf: Vector3,
		frame: CFrame,
		colour: Color3,
		material: Enum.Material
	)
		return Util.part({
			Name = name,
			Size = sizeOf,
			CFrame = frame,
			Color = colour,
			Material = material,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = model,
		})
	end
	-- The bracket runs from a little inside the rock out over the lantern.
	local bracketMiddle = wallPoint + out * ((reach - 1) / 2) + Vector3.new(0, size * 0.5 + 0.5, 0)
	piece(
		"Bracket",
		Vector3.new(0.2, 0.2, reach + 1),
		CFrame.lookAt(bracketMiddle, bracketMiddle + out),
		frameColour,
		Enum.Material.Metal
	)
	piece(
		"Cap",
		Vector3.new(size, 0.25, size),
		CFrame.new(hang + Vector3.new(0, size * 0.5 + 0.15, 0)),
		frameColour,
		Enum.Material.Metal
	)
	local glass = piece(
		"Glass",
		Vector3.new(size * 0.7, size, size * 0.7),
		CFrame.new(hang),
		Util.colour(hills.lanternColour),
		Enum.Material.Neon
	)
	piece(
		"Base",
		Vector3.new(size, 0.2, size),
		CFrame.new(hang - Vector3.new(0, size * 0.5 + 0.1, 0)),
		frameColour,
		Enum.Material.Metal
	)
	local light = Instance.new("PointLight")
	light.Color = Util.colour(hills.lanternColour)
	light.Range = hills.lanternRange
	light.Brightness = hills.lanternBrightness
	light.Shadows = true
	light.Parent = glass
end

local function hillsLanterns(parent: Instance)
	local hills = Map.Hills
	-- The nearest wall from (x, z) along (dx, dz) at height y: the point on
	-- the rock's surface, or nil when there's none within `reach`.
	local function findWall(
		x: number,
		y: number,
		z: number,
		dx: number,
		dz: number,
		reach: number
	): Vector3?
		local result =
			workspace:Raycast(Vector3.new(x, y, z), Vector3.new(dx, 0, dz) * reach, surfaceParams)
		return if result then result.Position else nil
	end
	-- The cave: lanterns on its two long walls, placed from the map data
	-- (where the solid rock cells start).
	local caveY = GROUND + hills.caveLanternHeight
	local spots = MapRules.caveLanternSpots(Map, HillsShape, MapRules.hillsGrid(Map, HillsShape))
	for _, spot in spots do
		wallLantern(parent, spot[1], spot[2], spot[3], spot[4], caveY)
	end
	print(`Hills: {#spots} cave lanterns placed`)
	-- Tunnels under rock: one every so often on the nearest wall.
	local spacing = hills.tunnelLanternSpacing
	local tunnelY = GROUND + hills.tunnelLanternHeight
	local x = spacing / 2
	while x < Map.halfSize do
		local z = -spacing / 2
		while z > -Map.halfSize do
			local bottom = MapRules.hillsRock(Map, HillsShape, x, z)
			if bottom == hills.tunnelRockBottom then
				local best: Vector3?, bestDx, bestDz, bestDistance = nil, 0, 0, math.huge
				for _, direction in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local wall = findWall(x, tunnelY, z, direction[1], direction[2], 10)
					if wall then
						local distance = (wall - Vector3.new(x, tunnelY, z)).Magnitude
						if distance < bestDistance then
							best, bestDx, bestDz, bestDistance =
								wall, direction[1], direction[2], distance
						end
					end
				end
				if best then
					wallLantern(parent, best.X, best.Z, -bestDx, -bestDz, tunnelY)
				end
			end
			z -= spacing
		end
		x += spacing
	end
	-- Along the tunnel through the bottom left hill, on alternate walls.
	local ridge = HillsShape.ridge
	local acrossX, acrossZ = -ridge.dz, ridge.dx
	local along = -ridge.length / 2 + spacing / 2
	local side = 1
	while along < ridge.length / 2 do
		local offset = side * (hills.ridgeTunnelWidth / 2)
		wallLantern(
			parent,
			ridge.x + ridge.dx * along + acrossX * offset,
			ridge.z + ridge.dz * along + acrossZ * offset,
			-acrossX * side,
			-acrossZ * side,
			GROUND + hills.tunnelLanternHeight
		)
		along += spacing
		side = -side
	end
end

-- A part shaped as an ellipsoid of the given size.
local function ellipsoid(
	parent: Instance,
	name: string,
	size: Vector3,
	frame: CFrame,
	colour: Color3
): Part
	local part = Util.part({
		Name = name,
		Size = size,
		CFrame = frame,
		Color = colour,
		Material = Enum.Material.Grass,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- A barrel cactus: a round ball of ribs with a pale top and pale spines.
-- It stands on `base`, a nearly round ball like a golden barrel cactus,
-- widest half way up.
local function barrelCactus(model: Model, base: CFrame, colour: Color3, radius: number)
	local hills = Map.Hills
	local middle = radius * 0.95
	ellipsoid(
		model,
		"Body",
		Vector3.new(radius * 1.9, radius * 1.9, radius * 1.9),
		base * CFrame.new(0, middle, 0),
		colour
	)
	local spineColour = Util.colour(hills.spineColour)
	local ribs = hills.barrelRibs
	for n = 1, ribs do
		local angle = n / ribs * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local ribCentre = (base * CFrame.new(out * radius * 0.62 + Vector3.new(0, middle, 0))).Position
		local outward = base:VectorToWorldSpace(out)
		ellipsoid(
			model,
			"Rib",
			Vector3.new(radius * 0.42, radius * 1.8, radius * 0.75),
			CFrame.lookAt(ribCentre, ribCentre + outward),
			if n % 2 == 0 then colour else colour:Lerp(Color3.new(0, 0, 0), 0.12)
		)
		for k = 1, hills.barrelSpinesPerRib do
			local up = radius * (0.45 + 1.0 * (k - 0.5) / hills.barrelSpinesPerRib)
			local root = ribCentre + outward * radius * 0.33 + Vector3.new(0, up - middle, 0)
			local length = radius * 0.45
			local direction = (outward + Vector3.new(0, 0.5, 0)).Unit
			Util.part({
				Name = "Spine",
				Size = Vector3.new(0.08, 0.08, length),
				CFrame = CFrame.lookAt(root + direction * length / 2, root + direction * length),
				Color = spineColour,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Parent = model,
			})
		end
	end
	ellipsoid(
		model,
		"Top",
		Vector3.new(radius * 1.1, radius * 0.35, radius * 1.1),
		base * CFrame.new(0, radius * 1.8, 0),
		Util.colour(hills.barrelTopColour)
	)
end

-- A cylinder between two points (for cactus arms).
local function cylinderBetween(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	diameter: number,
	colour: Color3
)
	local up = math.abs((b - a).Unit.Y) > 0.99
	Util.part({
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new((b - a).Magnitude, diameter, diameter),
		CFrame = if up
			then CFrame.new((a + b) / 2) * CFrame.Angles(0, 0, math.rad(90))
			else CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
		Color = colour,
		Material = Enum.Material.Grass,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	Util.part({
		Name = "Tip",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		Position = b,
		Color = colour,
		Material = Enum.Material.Grass,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
end

-- One cactus: "Ball", "Short" (two arms) or "Tall" (three arms).
local function cactus(parent: Instance, kind: string, base: CFrame, radius: number)
	local hills = Map.Hills
	local custom = ServerStorage:FindFirstChild("Cacti")
	local template = custom and custom:FindFirstChild(kind)
	if template and template:IsA("Model") then
		local copy = template:Clone()
		copy:PivotTo(base)
		copy.Parent = parent
		return
	end
	local model = Instance.new("Model")
	model.Name = `Cactus{kind}`
	model.Parent = parent
	local colour = variedColour(hills.cactusColour, 10)
	local function at(x: number, y: number, z: number): Vector3
		return (base * CFrame.new(x, y, z)).Position
	end
	if kind == "Ball" then
		barrelCactus(model, base, colour, radius)
		return
	end
	local range = if kind == "Tall" then hills.tallCactusHeight else hills.shortCactusHeight
	local height = Util.roll(range[1], range[2])
	local trunk = if kind == "Tall" then 1.9 else 1.5
	cylinderBetween(model, at(0, 0, 0), at(0, height, 0), trunk, colour)
	-- Each arm: sideways out from the trunk, then up. Side angle, height
	-- up the trunk, and how far up it reaches.
	local arms = if kind == "Tall"
		then { { 0, 0.4, 0.3 }, { 180, 0.55, 0.25 }, { 90, 0.7, 0.2 } }
		else { { 0, 0.4, 0.3 }, { 180, 0.5, 0.25 } }
	local armSize = trunk * 0.7
	for _, arm in arms do
		local turn = math.rad(arm[1])
		local dx, dz = math.cos(turn), math.sin(turn)
		local out = trunk * 1.1
		local y = height * arm[2]
		local elbow = at(dx * out, y, dz * out)
		cylinderBetween(model, at(dx * trunk * 0.3, y, dz * trunk * 0.3), elbow, armSize, colour)
		cylinderBetween(model, elbow, at(dx * out, y + height * arm[3], dz * out), armSize, colour)
	end
end

-- One cactus of the next kind at (x, z), standing on the surface. On the
-- ground it gets a patch of sand round its foot.
local cactusKinds = { "Ball", "Short", "Tall" }
local cactusCount = 0
local cactusLowest, cactusHighest = math.huge, -math.huge
local function placeCactus(parent: Instance, x: number, z: number)
	local hills = Map.Hills
	local cell = hills.terrainCell
	if not MapRules.onFirstHill(Map, HillsShape, x, z) then
		-- Sand in whole terrain cells round the foot (a terrain cell only
		-- changes material when a fill covers it fully).
		local radius = Util.roll(hills.cactusSandMin, hills.cactusSandMax) / 2
		local reach = radius + cell / 2
		local i0, i1 = math.floor((x - reach) / cell), math.floor((x + reach) / cell)
		local j0, j1 = math.floor((-z - reach) / cell), math.floor((-z + reach) / cell)
		for i = i0, i1 do
			for j = j0, j1 do
				local cx, cz = (i + 0.5) * cell, -(j + 0.5) * cell
				local _, top = MapRules.hillsRock(Map, HillsShape, cx, cz)
				if
					(cx - x) ^ 2 + (cz - z) ^ 2 <= reach * reach
					and top == 0
					and inHillsQuarter(cx, cz)
					and MapRules.rampAt(Map, HillsShape, cx, cz) == nil
				then
					workspace.Terrain:FillBlock(
						CFrame.new(cx, GROUND - cell / 2, cz),
						Vector3.new(cell, cell, cell),
						Enum.Material.Sand
					)
				end
			end
		end
	end
	-- Stand on the surface. Tall and short cacti are set in a little so
	-- they look planted. A barrel cactus sits on the highest ground under
	-- its whole ball (rays round its edge as well as its middle), lifted
	-- by `barrelLift`, so no part of it is buried.
	cactusCount += 1
	local kind = cactusKinds[(cactusCount - 1) % #cactusKinds + 1]
	local radius = Util.roll(hills.ballCactusSize[1], hills.ballCactusSize[2]) / 2
	local y
	if kind == "Ball" then
		y = surfaceY(x, z)
		for n = 1, 8 do
			local angle = n / 8 * math.pi * 2
			y = math.max(y, surfaceY(x + math.cos(angle) * radius, z + math.sin(angle) * radius))
		end
		if cactusCount == 1 then
			-- What the ray stands barrels on, to check against the ground
			-- seen in Studio.
			local hit = workspace:Raycast(
				Vector3.new(x, GROUND + 200, z),
				Vector3.new(0, -400, 0),
				surfaceParams
			)
			print(
				string.format(
					"Hills: first barrel ray hit %s (%s) at %.2f",
					if hit then hit.Instance:GetFullName() else "nothing",
					if hit then hit.Material.Name else "-",
					if hit then hit.Position.Y else 0
				)
			)
		end
		y += hills.barrelLift
	elseif kind == "Short" then
		y = surfaceY(x, z) + hills.shortCactusLift
	else
		y = surfaceY(x, z) - hills.cactusSink
	end
	cactusLowest, cactusHighest = math.min(cactusLowest, y), math.max(cactusHighest, y)
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, Util.random() * math.pi * 2, 0)
	cactus(parent, kind, base, radius)
end

local function hillsCacti(parent: Instance)
	local hills = Map.Hills
	local clear = hills.cactusClearance
	local placed, tries = 0, 0
	while placed < hills.cacti and tries < hills.cacti * 20 do
		tries += 1
		local x, z = MapRules.randomPointIn(Map, "Hills", Util.random)
		local open = MapRules.areaAt(Map, x, z, HillsShape) == "Land"
		for _, offset in { { 0, 0 }, { clear, 0 }, { -clear, 0 }, { 0, clear }, { 0, -clear } } do
			local px, pz = x + offset[1], z + offset[2]
			if
				MapRules.hillsHeight(Map, HillsShape, px, pz) > 0
				or MapRules.inTunnel(Map, HillsShape, px, pz)
				or MapRules.onFirstHill(Map, HillsShape, px, pz)
			then
				open = false
			end
		end
		if open then
			placeCactus(parent, x, z)
			placed += 1
		end
	end
end

-- Second Rise boulders round and on the ramps (keeping a clear path up
-- the middle), and in clusters on top of the bottom left hill.
local function hillsBoulders(rock: Instance)
	local hills = Map.Hills
	local sections = MapRules.rampSections(Map, HillsShape)
	for index = 3, #sections, 3 do
		local first, last = sections[index - 2], sections[index]
		local startX = first.x - first.ax * first.length / 2
		local startZ = first.z - first.az * first.length / 2
		local endX = last.x + last.ax * last.length / 2
		local endZ = last.z + last.az * last.length / 2
		local ax, az = endX - startX, endZ - startZ
		local total = math.sqrt(ax * ax + az * az)
		ax, az = ax / total, az / total
		local width = last.width
		local function place(along: number, out: number, maxSize: number)
			local x = startX + ax * along - az * out
			local z = startZ + az * along + ax * out
			if inHillsQuarter(x, z) and not MapRules.inTunnel(Map, HillsShape, x, z) then
				boulder(rock, x, z, maxSize)
			end
		end
		for _ = 1, hills.rampBoulders do
			local side = if Util.random() < 0.5 then -1 else 1
			place(
				Util.random() * total,
				side * (width / 2 + Util.roll(-3, 4)),
				hills.boulderMaxSize
			)
		end
		for _ = 1, hills.rampSurfaceBoulders do
			local side = if Util.random() < 0.5 then -1 else 1
			place(
				Util.between(0.1, 0.9) * total,
				side * width * Util.between(0.15, 0.42),
				hills.surfaceBoulderMaxSize
			)
		end
	end
	-- Clusters of boulders on the bottom left hill's rock patches.
	for _, patch in hills.firstHill.rockPatches do
		local area, minX, maxX, minZ, maxZ = 0, math.huge, -math.huge, math.huge, -math.huge
		for k, a in patch do
			local b = patch[k % #patch + 1]
			area += a[1] * b[2] - b[1] * a[2]
			minX, maxX = math.min(minX, a[1]), math.max(maxX, a[1])
			minZ, maxZ = math.min(minZ, a[2]), math.max(maxZ, a[2])
		end
		local count = math.max(1, math.floor(math.abs(area) / 2 / hills.firstHill.patchBoulderArea))
		local placed, tries = 0, 0
		while placed < count and tries < count * 20 do
			tries += 1
			local x, z = Util.roll(minX, maxX), Util.roll(minZ, maxZ)
			if MapRules.inPolygon(patch, x, z) then
				boulder(rock, x, z, hills.boulderMaxSize)
				placed += 1
			end
		end
	end
end

-- Cliff wall round the top and right edges, from the river bank to a tall
-- pillar where the Hills meet the Grassland.
local function hillsCliffWall(parent: Instance)
	local hills = Map.Hills
	local edge = Map.halfSize
	local thickness = hills.cliffThickness
	-- Most of the wall's thickness is outside the arena.
	local line = edge - thickness * 0.2
	local function rock(name: string, centre: Vector3, along: Vector3, size: Vector3)
		local frame = CFrame.lookAt(centre, centre + along)
			* CFrame.Angles(0, math.rad(Util.roll(-4, 4)), 0)
			* CFrame.Angles(0, 0, math.rad(Util.roll(-1, 1) * hills.cliffMaxTiltDegrees))
		Util.part({
			Name = name,
			Size = size,
			CFrame = frame,
			Color = variedColour(hills.cliffColour, hills.slabColourVariation),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
		-- Grass on top.
		Util.part({
			Name = "CliffGrass",
			Size = Vector3.new(size.X * 0.85, 0.8, size.Z * 0.9),
			CFrame = frame * CFrame.new(0, size.Y / 2 + 0.2, 0),
			Color = variedColour(hills.cliffGrassColour, 8),
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = parent,
		})
	end
	local function run(from: number, to: number, place: (position: number, length: number) -> ())
		local position = from
		while position < to do
			local length =
				math.min(Util.roll(hills.cliffMinLength, hills.cliffMaxLength), to - position)
			place(position + length / 2, length + 2)
			position += length
		end
	end
	local function height(): number
		return Util.roll(hills.cliffMinHeight, hills.cliffMaxHeight)
	end
	-- Top edge (local Z along the edge, so X is the thickness).
	run(hills.cliffStartX, edge, function(x, length)
		local tall = height()
		rock(
			"CliffWall",
			Vector3.new(x, GROUND + tall / 2 - 1, -line),
			Vector3.xAxis,
			Vector3.new(thickness, tall + 2, length)
		)
	end)
	-- Right edge, stopping at the pillar.
	run(hills.pillarSize, edge, function(z, length)
		local tall = height()
		rock(
			"CliffWall",
			Vector3.new(line, GROUND + tall / 2 - 1, -z),
			Vector3.zAxis,
			Vector3.new(thickness, tall + 2, length)
		)
	end)
	local size = hills.pillarSize
	rock(
		"CliffPillar",
		Vector3.new(edge - size / 2 + 2, GROUND + hills.pillarHeight / 2 - 1, -size / 2),
		Vector3.zAxis,
		Vector3.new(size, hills.pillarHeight + 2, size)
	)
end

-- The Hills: walkable rock goes in `Hills` (seen by the ground ray, with
-- the terrain); cacti and lanterns in `HillsDecor`.
local function buildHills()
	local hills = Instance.new("Folder")
	hills.Name = "Hills"
	hills.Parent = folder
	local decor = Instance.new("Folder")
	decor.Name = "HillsDecor"
	decor.Parent = folder
	local terrain = workspace.Terrain
	local grid = MapRules.hillsGrid(Map, HillsShape)
	hillsGround(terrain, grid)
	hillsRock(terrain, grid)
	hillsArches(hills, grid)
	hillsSlabs(hills)
	hillsRamps(hills)
	hillsRidge(hills)
	hillsCliffWall(hills)
	-- Things set on the built surface.
	surfaceParams.FilterDescendantsInstances = { decor }
	hillsLanterns(decor)
	hillsBoulders(hills)
	hillsCacti(decor)
	print(
		string.format(
			"Hills: %d cacti, feet from %.1f to %.1f studs high; %d surface rays missed",
			cactusCount,
			cactusLowest,
			cactusHighest,
			surfaceMisses
		)
	)
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

-- A see-through grass dome at (x, z): flat on top, `Grassland.domeHeight`
-- up, with a rounded edge down to the ground at `radius`. A middle
-- cylinder and a ring of balls round its edge, joined into one part; if
-- the join fails the pieces stay as they are.
local function grassDome(parent: Instance, x: number, z: number, radius: number)
	local land = Map.Grassland
	local height = land.domeHeight
	local look = {
		Color = Util.colour(land.fillColour),
		Material = Enum.Material.Grass,
		Transparency = land.fillTransparency,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}
	local function piece(props: { [string]: any }): Part
		for key, value in look do
			props[key] = value
		end
		props.Parent = parent
		return Util.part(props)
	end
	-- Everything is centred on the ground, so only the top half shows.
	local inner = radius - height
	local core = piece({
		Name = "TallGrass",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height * 2, inner * 2, inner * 2),
		CFrame = CFrame.new(x, GROUND, z) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local balls = {}
	local count = math.ceil(2 * math.pi * inner / land.domeEdgeSpacing)
	for i = 0, count - 1 do
		local angle = i / count * 2 * math.pi
		table.insert(
			balls,
			piece({
				Name = "TallGrassEdge",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(height * 2, height * 2, height * 2),
				Position = Vector3.new(
					x + math.cos(angle) * inner,
					GROUND,
					z + math.sin(angle) * inner
				),
			})
		)
	end
	local ok, union = pcall(function()
		return core:UnionAsync(balls)
	end)
	if ok and union then
		union.Name = "TallGrass"
		union.UsePartColor = true
		for key, value in look do
			(union :: any)[key] = value
		end
		union.Anchored = true
		union.Parent = parent
		core:Destroy()
		for _, ball in balls do
			ball:Destroy()
		end
	else
		warn("[MapBuilder] Grass dome join failed, using loose pieces:", union)
	end
end

local function buildGrassland()
	local grass = Instance.new("Folder")
	grass.Name = "Grassland"
	grass.Parent = folder
	grassGround(1, 1, function(x, z)
		return MapRules.grasslandGrassGround(Map, x, z)
	end)
	-- Hiding grass circles: a low see-through grass dome with rows of
	-- waving blades round the edge and a few scattered inside.
	local land = Map.Grassland
	local hiding = Map.HidingGrass
	local blades = Instance.new("Model")
	blades.Name = "HidingGrass"
	blades.Parent = grass
	for _, circle in land.grassCircles do
		grassDome(grass, circle.x, circle.z, MapRules.grassDomeRadius(Map, circle.radius))
		local spacing = hiding.bladeSpacing
		local spread = hiding.bladeSpread
		-- Blades scattered inside, clear of the innermost ring.
		local inner = MapRules.grassRingRadius(Map, circle.radius, land.ringRows - 1) - spacing
		for _ = 1, land.bladesInside do
			local angle = Util.random() * 2 * math.pi
			local distance = inner * math.sqrt(Util.random())
			grassBlade(
				blades,
				circle.x + math.cos(angle) * distance,
				circle.z + math.sin(angle) * distance
			)
		end
		for row = 0, land.ringRows - 1 do
			local ringRadius = MapRules.grassRingRadius(Map, circle.radius, row)
			local count = math.floor(2 * math.pi * ringRadius / spacing)
			local shift = if row % 2 == 0 then 0 else 0.5
			for i = 0, count - 1 do
				local angle = (i + shift) / count * 2 * math.pi
				grassBlade(
					blades,
					circle.x + math.cos(angle) * ringRadius + Util.between(-spread, spread),
					circle.z + math.sin(angle) * ringRadius + Util.between(-spread, spread)
				)
			end
		end
	end
	for _, field in Map.Grassland.cowFields do
		local half = field.size / 2
		Util.part({
			Name = "PenDirt",
			Size = Vector3.new(field.size, 0.2, field.size),
			Position = Vector3.new(field.x, GROUND + 0.1, field.z),
			Color = Util.colour(Map.Grassland.penDirtColour),
			Material = Enum.Material.Ground,
			Parent = grass,
		})
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

-- Where a plant at `position` gets out of a tunnel or the cave (on the
-- ground there), or nil when it isn't in one.
function MapBuilder.tunnelExit(position: Vector3): Vector3?
	local x, z = MapRules.tunnelExit(Map, HillsShape, position.X, position.Z)
	if x == nil or z == nil then
		return nil
	end
	return Vector3.new(x, MapBuilder.groundY(x, z), z)
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
	-- The ground ray only looks at walkable ground, not trees or grass
	-- (terrain is the Hills rock; water is skipped).
	rayParams.IgnoreWater = true
	rayParams.FilterDescendantsInstances = {
		workspace.Terrain,
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
