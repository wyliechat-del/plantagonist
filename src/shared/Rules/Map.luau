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

-- Height of a rise's top at a point: the tall pillar has its own heights.
function MapRules.riseHeight(map: any, layer: number, x: number, z: number): number
	local config = map.Hills
	local pillar = config.pillar
	if (x - pillar.x) ^ 2 + (z - pillar.z) ^ 2 <= pillar.radius ^ 2 then
		return pillar.heights[layer]
	end
	return config.riseHeights[layer]
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

-- The pieces of each ramp up to the First Rise: a lower slope, a flat
-- ledge and an upper slope, each turned a little from the others. The
-- ramp runs `rampExtend` studs further out into the ground than drawn.
-- Each piece: middle (x, z), uphill direction (ax, az), length, width,
-- and its height at the low and high ends.
local sectionCache: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any

function MapRules.rampSections(map: any, hills: any): { { [string]: number } }
	local cached = sectionCache[hills]
	if cached and cached.map == map then
		return cached.sections
	end
	local config = map.Hills
	local rise = config.riseHeights[1]
	local ledge = config.rampLedgeHeight
	local split = config.rampSplit
	local sections = {}
	for _, ramp in hills.ramps do
		local h1, h2 = ramp.high[1], ramp.high[2]
		local l1, l2 = ramp.low[1], ramp.low[2]
		local hx, hz = (h1[1] + h2[1]) / 2, (h1[2] + h2[2]) / 2
		local lx, lz = (l1[1] + l2[1]) / 2, (l1[2] + l2[2]) / 2
		local drawn = math.sqrt((hx - lx) ^ 2 + (hz - lz) ^ 2)
		local ux, uz = (hx - lx) / drawn, (hz - lz) / drawn
		local width = math.sqrt((h2[1] - h1[1]) ^ 2 + (h2[2] - h1[2]) ^ 2)
		local total = drawn + config.rampExtend
		local startX, startZ = hx - ux * total, hz - uz * total
		local pieces = {
			{
				from = 0,
				to = split[1],
				low = 0,
				high = ledge,
				turn = 1,
				scale = 0.92,
				shift = 0.03,
			},
			{
				from = split[1],
				to = split[2],
				low = ledge,
				high = ledge,
				turn = 0,
				scale = 0.96,
				shift = 0,
			},
			{ from = split[2], to = 1, low = ledge, high = rise, turn = -1, scale = 1, shift = 0 },
		}
		for _, piece in pieces do
			local angle = math.rad(config.rampTurnDegrees * piece.turn)
			local ax = ux * math.cos(angle) - uz * math.sin(angle)
			local az = ux * math.sin(angle) + uz * math.cos(angle)
			local middle = total * (piece.from + piece.to) / 2
			local side = width * piece.shift
			table.insert(sections, {
				x = startX + ux * middle - uz * side,
				z = startZ + uz * middle + ux * side,
				ax = ax,
				az = az,
				-- A little longer, so the pieces overlap with no gap.
				length = total * (piece.to - piece.from) + 1,
				width = width * piece.scale,
				low = piece.low,
				high = piece.high,
			})
		end
	end
	sectionCache[hills] = { map = map, sections = sections }
	return sections
end

-- Height of the ramps at a point (the highest piece there), or nil when
-- the point isn't on a ramp.
function MapRules.rampAt(map: any, hills: any, x: number, z: number): number?
	local best = nil
	for _, section in MapRules.rampSections(map, hills) do
		local rx, rz = x - section.x, z - section.z
		local along = rx * section.ax + rz * section.az
		local across = -rx * section.az + rz * section.ax
		if math.abs(along) <= section.length / 2 and math.abs(across) <= section.width / 2 then
			local share = along / section.length + 0.5
			local height = section.low + (section.high - section.low) * share
			best = if best then math.max(best, height) else height
		end
	end
	return best
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

-- The terrain rock at a point on a rise: from `bottom` to `top` above the
-- ground, and the rise. Over a tunnel or the cave the rock starts above
-- the arched roof (bottom > 0), and may be empty when the roof parts reach
-- the top. Ramps and the bottom left hill are parts, so no rock there.
function MapRules.hillsRock(map: any, hills: any, x: number, z: number): (number, number, number)
	if MapRules.rampAt(map, hills, x, z) ~= nil or MapRules.ridgeOffset(hills, x, z) then
		return 0, 0, 0
	end
	local layer = MapRules.hillsLayer(hills, x, z)
	if layer == 0 then
		return 0, 0, 0
	end
	local config = map.Hills
	local top = MapRules.riseHeight(map, layer, x, z)
	if MapRules.inCave(hills, x, z) then
		return config.caveRockBottom, math.max(top, config.caveRockTop), layer
	end
	for _, outline in hills.tunnels do
		if MapRules.inPolygon(outline, x, z) then
			return config.tunnelRockBottom, math.max(top, config.tunnelRockBottom), layer
		end
	end
	return 0, top, layer
end

-- The Hills on a grid of terrain cells (`terrainCell` studs): cells[j][i]
-- is { bottom, top, layer } (from `hillsRock`) for the cell whose middle
-- is x = (i - 0.5) * cell, z = -(j - 0.5) * cell.
function MapRules.hillsGrid(map: any, hills: any): { { { number } } }
	local cell = map.Hills.terrainCell
	local count = math.ceil(map.halfSize / cell)
	local rows = {}
	for j = 1, count do
		local row = {}
		for i = 1, count do
			local bottom, top, layer =
				MapRules.hillsRock(map, hills, (i - 0.5) * cell, -(j - 0.5) * cell)
			row[i] = { bottom, top, layer }
		end
		rows[j] = row
	end
	return rows
end

-- Distance from a point to the nearest cell of the grid that passes
-- `isSolid(entry)`, looking no further than `reach` (returns `reach` when
-- none is closer). Off the grid counts as solid when `edgeSolid`.
function MapRules.distanceToCells(
	map: any,
	grid: { { { number } } },
	x: number,
	z: number,
	reach: number,
	isSolid: ({ number }) -> boolean,
	edgeSolid: boolean
): number
	local cell = map.Hills.terrainCell
	local count = #grid
	local ci, cj = math.floor(x / cell) + 1, math.floor(-z / cell) + 1
	local span = math.ceil(reach / cell) + 1
	local best = reach
	for j = cj - span, cj + span do
		for i = ci - span, ci + span do
			local solid
			if i < 1 or j < 1 or i > count or j > count then
				solid = edgeSolid
			else
				solid = isSolid(grid[j][i])
			end
			if solid then
				-- Distance to the cell's square.
				local x0, x1 = (i - 1) * cell, i * cell
				local z0, z1 = -j * cell, -(j - 1) * cell
				local dx = math.max(x0 - x, 0, x - x1)
				local dz = math.max(z0 - z, 0, z - z1)
				best = math.min(best, math.sqrt(dx * dx + dz * dz))
			end
		end
	end
	return best
end

-- A cell of solid rock from the ground up (a tunnel or cave wall).
function MapRules.isWallCell(entry: { number }): boolean
	return entry[2] > 0 and entry[1] == 0
end

-- Height of an arched roof `distance` studs from the nearest wall: `wall`
-- at the wall, rising in a quarter circle to `clearance` at `reach`.
function MapRules.archHeight(
	wall: number,
	clearance: number,
	reach: number,
	distance: number
): number
	local share = math.clamp(distance / reach, 0, 1)
	return wall + (clearance - wall) * math.sqrt(1 - (1 - share) ^ 2)
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
	local ramp = MapRules.rampAt(map, hills, x, z)
	if ramp then
		return ramp
	end
	local onRidge, _, across = MapRules.ridgeOffset(hills, x, z)
	if onRidge then
		return MapRules.ridgeHeight(map, hills, across)
	end
	local _, top = MapRules.hillsRock(map, hills, x, z)
	return top
end

-- Width of the sand at the foot of the cliffs near a point: wanders
-- between the min and max width so it isn't an even strip.
function MapRules.cliffSandWidth(map: any, x: number, z: number): number
	local config = map.Hills
	local wave = math.sin(x * 0.11 + z * 0.05) * math.sin(z * 0.13 - x * 0.04 + 1.7)
	local share = 0.5 + 0.5 * wave
	return config.cliffSandMinWidth + (config.cliffSandMaxWidth - config.cliffSandMinWidth) * share
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
		if MapRules.rampAt(map, hills, x, z) == nil and not MapRules.ridgeOffset(hills, x, z) then
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
