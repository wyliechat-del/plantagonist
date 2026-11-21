--[[
	Where things are on the map. Positions are plain X and Z numbers (studs).
	Takes `Config/Map.luau` as `map`.
]]

local MapRules = {}

local function inRect(rect: any, x: number, z: number): boolean
	return x >= rect.minX and x <= rect.maxX and z >= rect.minZ and z <= rect.maxZ
end

function MapRules.distanceFromCentre(x: number, z: number): number
	return math.sqrt(x * x + z * z)
end

function MapRules.inField(map: any, x: number, z: number): boolean
	return MapRules.distanceFromCentre(x, z) <= map.Field.radius
end

-- Which territory a point is in: "Grassland", "Forest", "River", "Hills", or
-- "Field" inside the safe field.
function MapRules.territoryAt(map: any, x: number, z: number): string
	if MapRules.inField(map, x, z) then
		return "Field"
	end
	for name, territory in map.territories do
		if math.sign(x) == territory.signX and math.sign(z) == territory.signZ then
			return name
		end
	end
	-- Exactly on an axis: lean towards positive values.
	if x >= 0 then
		return if z >= 0 then "Grassland" else "Hills"
	end
	return if z >= 0 then "Forest" else "River"
end

function MapRules.canBeInField(map: any, level: number): boolean
	return level <= map.Field.maxLevel
end

-- Where a plant inside the field ends up when pushed out: straight outwards,
-- just past the edge.
function MapRules.pushOut(map: any, x: number, z: number): (number, number)
	local distance = MapRules.distanceFromCentre(x, z)
	local target = map.Field.radius + map.Field.pushOutMargin
	if distance < 0.001 then
		return target, 0
	end
	return x / distance * target, z / distance * target
end

-- The angles (degrees, 0 = +X, counter-clockwise towards +Z) of the 12 exits.
function MapRules.exitAngles(map: any): { number }
	local angles = {}
	for quarter = 0, 3 do
		for _, offset in map.Field.exitAnglesInQuarter do
			table.insert(angles, quarter * 90 + offset)
		end
	end
	return angles
end

-- Is `angle` (degrees) inside one of the exit gaps?
function MapRules.isExitAngle(map: any, angle: number): boolean
	local half = map.Field.exitWidthDegrees / 2
	for _, exit in MapRules.exitAngles(map) do
		local difference = math.abs(((angle - exit + 180) % 360) - 180)
		if difference <= half then
			return true
		end
	end
	return false
end

-- Share of normal speed for a plant at (x, z), given its level and whether
-- it is standing on something above the ground (a bridge or lily pad).
function MapRules.speedFactor(
	map: any,
	level: number,
	x: number,
	z: number,
	raised: boolean
): number
	if raised then
		return 1
	end
	if inRect(map.Swamp, x, z) and level >= map.Swamp.slowFromLevel then
		return map.Swamp.speedFactor
	end
	if inRect(map.River, x, z) then
		return map.River.speedFactor
	end
	return 1
end

-- A random point in a territory, outside the field and away from the edges.
-- `random()` returns a number in [0, 1).
function MapRules.randomPointIn(map: any, territory: string, random: () -> number): (number, number)
	local info = map.territories[territory]
	assert(info, `unknown territory "{territory}"`)
	local low = map.edgeMargin
	local high = map.halfSize - map.edgeMargin
	local x, z = high, high
	for _ = 1, 20 do
		x = low + random() * (high - low)
		z = low + random() * (high - low)
		if MapRules.distanceFromCentre(x, z) > map.Field.radius + map.edgeMargin then
			break
		end
	end
	return x * info.signX, z * info.signZ
end

-- Keeps a point inside a territory's quarter (and outside the field).
function MapRules.clampToTerritory(
	map: any,
	territory: string,
	x: number,
	z: number
): (number, number)
	local info = map.territories[territory]
	local low = map.edgeMargin
	local high = map.halfSize - map.edgeMargin
	local ax = math.clamp(x * info.signX, low, high)
	local az = math.clamp(z * info.signZ, low, high)
	local distance = MapRules.distanceFromCentre(ax, az)
	local minimum = map.Field.radius + map.edgeMargin
	if distance < minimum then
		ax, az = ax / distance * minimum, az / distance * minimum
	end
	return ax * info.signX, az * info.signZ
end

return table.freeze(MapRules)
