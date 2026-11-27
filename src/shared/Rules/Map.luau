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
-- Hills ----------------------------------------------------------------
-- These take `hills`, the traced outlines from `Config/HillsShape.luau`.

-- Which rise (0 for the ground, 1 to 3) a point is on, from the outlines
-- alone (ramps and the bottom left hill aren't rises).
function MapRules.hillsLayer(hills: any, x: number, z: number): number
	for layer = #hills.rises, 1, -1 do
		for _, outline in hills.rises[layer] do
			if MapRules.inPolygon(outline, x, z) then
				return layer
			end
		end
	end
	return 0
end

-- A point's place on the bottom left hill: distance along its length and
-- across it from the middle, and whether it is on the hill.
function MapRules.ridgeOffset(hills: any, x: number, z: number): (boolean, number, number)
	local ridge = hills.ridge
	local rx, rz = x - ridge.x, z - ridge.z
	local along = rx * ridge.dx + rz * ridge.dz
	local across = -rx * ridge.dz + rz * ridge.dx
	local inside = math.abs(along) <= ridge.length / 2 and math.abs(across) <= ridge.width / 2
	return inside, along, across
end

-- The ramp (if any) a point is on, and how far up it is (0 at the low
-- edge, 1 at the high edge).
function MapRules.rampAt(hills: any, x: number, z: number): (any, number)
	for _, ramp in hills.ramps do
		local outline = { ramp.high[1], ramp.high[2], ramp.low[2], ramp.low[1] }
		if MapRules.inPolygon(outline, x, z) then
			-- Distance from the low edge, over the ramp's length.
			local lx, lz = ramp.low[1][1], ramp.low[1][2]
			local ex, ez = ramp.low[2][1] - lx, ramp.low[2][2] - lz
			local edge = math.sqrt(ex * ex + ez * ez)
			local nx, nz = -ez / edge, ex / edge
			local length = (ramp.high[1][1] - lx) * nx + (ramp.high[1][2] - lz) * nz
			local share = ((x - lx) * nx + (z - lz) * nz) / length
			return ramp, math.clamp(share, 0, 1)
		end
	end
	return nil, 0
end

function MapRules.inCave(hills: any, x: number, z: number): boolean
	for _, outline in hills.caveRooms do
		if MapRules.inPolygon(outline, x, z) then
			return true
		end
	end
	return false
end

-- Is a point in a tunnel (or the cave, or the tunnel through the bottom
-- left hill)? Tunnel mouths outside the rock count too.
function MapRules.inTunnel(map: any, hills: any, x: number, z: number): boolean
	for _, outline in hills.tunnels do
		if MapRules.inPolygon(outline, x, z) then
			return true
		end
	end
	if MapRules.inCave(hills, x, z) then
		return true
	end
	local onRidge, _, across = MapRules.ridgeOffset(hills, x, z)
	return onRidge and math.abs(across) <= map.Hills.ridgeTunnelWidth / 2
end

-- The solid rock at a point on a rise: from `bottom` to `top` above the
-- ground (bottom is above 0 over a tunnel or the cave), and the rise.
-- Ramps and the bottom left hill are built separately, so they have no
-- rock here (bottom == top).
function MapRules.hillsRock(map: any, hills: any, x: number, z: number): (number, number, number)
	if MapRules.rampAt(hills, x, z) ~= nil or MapRules.ridgeOffset(hills, x, z) then
		return 0, 0, 0
	end
	local layer = MapRules.hillsLayer(hills, x, z)
	if layer == 0 then
		return 0, 0, 0
	end
	local config = map.Hills
	local top = config.riseHeights[layer]
	if MapRules.inCave(hills, x, z) then
		return config.caveClearance + config.roofThickness, math.max(top, config.caveRockTop), layer
	end
	for _, outline in hills.tunnels do
		if MapRules.inPolygon(outline, x, z) then
			return config.tunnelClearance + config.roofThickness,
				math.max(top, config.tunnelRockTop),
				layer
		end
	end
	return 0, top, layer
end

-- Height of the bottom left hill's surface `across` studs from its middle
-- line: flat over the tunnel, sloping down to the ground at both sides.
function MapRules.ridgeHeight(map: any, hills: any, across: number): number
	local config = map.Hills
	local flat = config.ridgeFlatTop / 2
	local half = hills.ridge.width / 2
	local distance = math.abs(across)
	if distance <= flat then
		return config.ridgeHeight
	end
	return math.max(0, config.ridgeHeight * (1 - (distance - flat) / (half - flat)))
end

-- Height of the walkable surface above the ground at a point.
function MapRules.hillsHeight(map: any, hills: any, x: number, z: number): number
	local ramp, share = MapRules.rampAt(hills, x, z)
	if ramp then
		return share * map.Hills.riseHeights[1]
	end
	local onRidge, _, across = MapRules.ridgeOffset(hills, x, z)
	if onRidge then
		return MapRules.ridgeHeight(map, hills, across)
	end
	local _, top = MapRules.hillsRock(map, hills, x, z)
	return top
end

-- Which area a point is in, for creatures: "Water", "Marsh", "Tunnel",
-- "FirstRise", "ThirdRise" or "Land". Without `hills`, the Hills count as
-- land.
function MapRules.areaAt(map: any, x: number, z: number, hills: any?): string
	if MapRules.inRiver(map, x, z) then
		return "Water"
	end
	if MapRules.inMarsh(map, x, z) then
		return "Marsh"
	end
	if hills and x > 0 and z < 0 then
		if MapRules.inTunnel(map, hills, x, z) then
			return "Tunnel"
		end
		if MapRules.rampAt(hills, x, z) == nil and not MapRules.ridgeOffset(hills, x, z) then
			local layer = MapRules.hillsLayer(hills, x, z)
			if layer == 1 then
				return "FirstRise"
			elseif layer == 3 then
				return "ThirdRise"
			end
		end
	end
	return "Land"
end

-- May a creature that belongs in `home` (from `creatureArea`) be in
-- `area`? Land creatures may also go on the First Rise.
function MapRules.creatureAllowed(home: string, area: string): boolean
	return area == home or (home == "Land" and area == "FirstRise")
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

-- Upward speed that lifts a frog hop `height` studs under `gravity`
-- (studs per second squared).
function MapRules.hopLaunchSpeed(gravity: number, height: number): number
	return math.sqrt(2 * gravity * height)
end

-- All lily pads: the guide positions from the map, plus `extraPadsPer` more
-- round each one, on the marsh, clear of the edge and of other pads. Uses
-- its own fixed-seed random numbers, so every server builds the same marsh.
function MapRules.lilyPadLayout(map: any): { { number } }
	local pads = map.LilyPads
	local seed = pads.layoutSeed
	local function random(): number
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
	local placed = {}
	for _, position in pads.positions do
		table.insert(placed, { position[1], position[2] })
	end
	local limit = map.halfSize - map.edgeMargin
	local minGap = pads.size * (1 + pads.sizeVariation) + 0.5
	local function clear(x: number, z: number): boolean
		if math.abs(x) > limit or math.abs(z) > limit or not MapRules.inMarsh(map, x, z) then
			return false
		end
		for _, other in placed do
			if (other[1] - x) ^ 2 + (other[2] - z) ^ 2 < minGap * minGap then
				return false
			end
		end
		return true
	end
	for _, position in pads.positions do
		local added, tries = 0, 0
		while added < pads.extraPadsPer and tries < 40 do
			tries += 1
			local angle = random() * math.pi * 2
			local distance = pads.extraMinDistance
				+ random() * (pads.extraMaxDistance - pads.extraMinDistance)
			local x = position[1] + math.cos(angle) * distance
			local z = position[2] + math.sin(angle) * distance
			if clear(x, z) then
				table.insert(placed, { x, z })
				added += 1
			end
		end
	end
	return placed
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

-- A random point in a territory where a creature from `home` may be (see
-- `creatureAllowed`). Falls back to any point in the territory if none is
-- found.
function MapRules.randomPointInArea(
	map: any,
	territory: string,
	home: string,
	random: () -> number,
	hills: any?
): (number, number)
	local x, z = MapRules.randomPointIn(map, territory, random)
	for _ = 1, map.areaPointTries do
		if MapRules.creatureAllowed(home, MapRules.areaAt(map, x, z, hills)) then
			return x, z
		end
		x, z = MapRules.randomPointIn(map, territory, random)
	end
	return x, z
end

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
