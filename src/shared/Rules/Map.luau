--[[
	Where things are on the map. Positions are plain X and Z numbers (studs).
	Takes `Config/Map.luau` as `map`.
]]

local MapRules = {}

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

-- Closest point on a line through `points` ({ x, z } pairs) to (x, z).
-- Returns the distance to it, and the line's direction there (a unit
-- vector `dx`, `dz`).
function MapRules.closestOnLine(
	points: { { number } },
	x: number,
	z: number
): (number, number, number)
	local best, bestDx, bestDz = math.huge, 1, 0
	for i = 1, #points - 1 do
		local ax, az = points[i][1], points[i][2]
		local bx, bz = points[i + 1][1], points[i + 1][2]
		local sx, sz = bx - ax, bz - az
		local lengthSquared = sx * sx + sz * sz
		if lengthSquared > 0 then
			local t = math.clamp(((x - ax) * sx + (z - az) * sz) / lengthSquared, 0, 1)
			local px, pz = ax + sx * t, az + sz * t
			local distance = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
			if distance < best then
				local length = math.sqrt(lengthSquared)
				best, bestDx, bestDz = distance, sx / length, sz / length
			end
		end
	end
	return best, bestDx, bestDz
end

-- Is (x, z) inside the polygon `outline` ({ x, z } corners)?
function MapRules.inPolygon(outline: { { number } }, x: number, z: number): boolean
	local inside = false
	local j = #outline
	for i = 1, #outline do
		local xi, zi = outline[i][1], outline[i][2]
		local xj, zj = outline[j][1], outline[j][2]
		if (zi > z) ~= (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- Evenly spaced points along a line, `step` studs apart, starting
-- `startOffset` in. Each is { x, z, dx, dz } with the line's direction.
function MapRules.pointsAlong(
	points: { { number } },
	step: number,
	startOffset: number
): { { number } }
	local result = {}
	local carry = startOffset
	for i = 1, #points - 1 do
		local ax, az = points[i][1], points[i][2]
		local bx, bz = points[i + 1][1], points[i + 1][2]
		local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		if length > 0 then
			local dx, dz = (bx - ax) / length, (bz - az) / length
			local along = carry
			while along <= length do
				table.insert(result, { ax + dx * along, az + dz * along, dx, dz })
				along += step
			end
			carry = along - length
		end
	end
	return result
end

function MapRules.inRiver(map: any, x: number, z: number): boolean
	local distance = MapRules.closestOnLine(map.River.centreLine, x, z)
	return distance <= map.River.width / 2
end

function MapRules.onPath(map: any, x: number, z: number): boolean
	local distance = MapRules.closestOnLine(map.Path.centreLine, x, z)
	return distance <= map.Path.width / 2
end

function MapRules.inMarsh(map: any, x: number, z: number): boolean
	return MapRules.inPolygon(map.Marsh.outline, x, z)
		and not MapRules.inRiver(map, x, z)
		and not MapRules.onPath(map, x, z)
end

-- "Water", "Marsh" or "Land": what kind of ground (x, z) is.
function MapRules.areaAt(map: any, x: number, z: number): string
	if MapRules.inRiver(map, x, z) then
		return "Water"
	end
	if MapRules.inMarsh(map, x, z) then
		return "Marsh"
	end
	return "Land"
end

function MapRules.inHidingGrass(map: any, x: number, z: number): boolean
	for _, circle in map.HidingGrass.circles do
		if (x - circle.x) ^ 2 + (z - circle.z) ^ 2 <= circle.radius ^ 2 then
			return true
		end
	end
	return false
end

-- Is a plant hidden from other players? Only small plants hide, and not
-- while revealed by their own attack.
function MapRules.hiddenInGrass(
	map: any,
	level: number,
	x: number,
	z: number,
	now: number,
	revealedUntil: number
): boolean
	return level <= map.HidingGrass.hideMaxLevel
		and now >= revealedUntil
		and MapRules.inHidingGrass(map, x, z)
end

-- Height of the moon bridge deck above the ground at `offset` studs from its
-- middle (along the bridge): a parabola, 0 at the banks.
function MapRules.moonBridgeHeight(map: any, offset: number): number
	local bridge = map.MoonBridge
	local share = offset / (bridge.span / 2)
	return math.max(0, bridge.rise * (1 - share * share))
end

-- Height of the rope bridge deck above the ground at `offset` studs from its
-- middle: sags in the middle.
function MapRules.ropeBridgeHeight(map: any, offset: number): number
	local bridge = map.RopeBridge
	local share = math.clamp(offset / (bridge.length / 2), -1, 1)
	return bridge.endHeight - bridge.sag * (1 - share * share)
end

-- Upward speed that keeps a frog hop in the air for `seconds` under
-- `gravity` (studs per second squared).
function MapRules.hopLaunchSpeed(gravity: number, seconds: number): number
	return gravity * seconds / 2
end

-- Share of normal speed for a plant at (x, z), given its level and whether
-- it is standing on something above the ground (a bridge, rock or lily pad).
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
	if MapRules.inRiver(map, x, z) then
		return map.River.speedFactor
	end
	if level >= map.Marsh.slowFromLevel and MapRules.inMarsh(map, x, z) then
		return map.Marsh.speedFactor
	end
	return 1
end

-- Which area a creature spawns and wanders in: its own area from
-- `map.CreatureAreas` when it is native to the territory, otherwise "Land".
function MapRules.creatureArea(map: any, id: string, native: boolean): string
	local area = map.CreatureAreas[id]
	if native and area then
		return area
	end
	return "Land"
end

-- A random point in a territory and area ("Water", "Marsh" or "Land").
-- Falls back to any point in the territory if none is found.
function MapRules.randomPointInArea(
	map: any,
	territory: string,
	area: string,
	random: () -> number
): (number, number)
	local x, z = MapRules.randomPointIn(map, territory, random)
	for _ = 1, 60 do
		if MapRules.areaAt(map, x, z) == area then
			return x, z
		end
		x, z = MapRules.randomPointIn(map, territory, random)
	end
	return x, z
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

-- Neighbouring and opposite territories of `territory` (by quarter).
function MapRules.relatives(map: any, territory: string): ({ string }, string?)
	local info = map.territories[territory]
	local neighbours, opposite = {}, nil
	for name, other in map.territories do
		if other.signX == -info.signX and other.signZ == -info.signZ then
			opposite = name
		elseif name ~= territory then
			table.insert(neighbours, name)
		end
	end
	table.sort(neighbours)
	return neighbours, opposite
end

-- Which territory's creatures spawn in `territory` this time, using `mix`
-- ({ native, neighbour, opposite } shares). `random()` returns [0, 1).
function MapRules.spawnSource(map: any, territory: string, mix: any, random: () -> number): string
	local roll = random()
	if roll < mix.native then
		return territory
	end
	local neighbours, opposite = MapRules.relatives(map, territory)
	if roll < mix.native + mix.neighbour and #neighbours > 0 then
		return neighbours[math.floor(random() * #neighbours) + 1]
	end
	return opposite or territory
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
