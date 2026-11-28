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

-- Half the width of the bottom left hill's tunnel with its side walls
-- (the parts down the middle of the hill).
function MapRules.ridgeBandHalf(map: any): number
	return map.Hills.ridgeTunnelWidth / 2 + map.Hills.ridgeWallWidth
end

-- Is a point on the bottom left hill: inside its outline, or on its
-- tunnel and walls?
function MapRules.onFirstHill(map: any, hills: any, x: number, z: number): boolean
	if MapRules.inPolygon(map.Hills.firstHill.outline, x, z) then
		return true
	end
	local _, along, across = MapRules.ridgeOffset(hills, x, z)
	return math.abs(along) <= hills.ridge.length / 2
		and math.abs(across) <= MapRules.ridgeBandHalf(map)
end

-- The pieces of each ramp up to the First Rise: a lower slope, a flat
-- ledge and an upper slope, each turned a little from the others. The
-- ramp runs `rampExtend` studs further out into the ground than drawn
-- (`firstHill.rampExtend` for the bottom left hill's ramps).
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
	local ramps = {}
	for _, ramp in hills.ramps do
		table.insert(ramps, { ramp = ramp, firstHill = 0, extend = config.rampExtend })
	end
	for _, ramp in config.firstHill.ramps do
		table.insert(ramps, { ramp = ramp, firstHill = 1, extend = config.firstHill.rampExtend })
	end
	for index, entry in ramps do
		local ramp = entry.ramp
		local h1, h2 = ramp.high[1], ramp.high[2]
		local l1, l2 = ramp.low[1], ramp.low[2]
		local hx, hz = (h1[1] + h2[1]) / 2, (h1[2] + h2[2]) / 2
		local lx, lz = (l1[1] + l2[1]) / 2, (l1[2] + l2[2]) / 2
		local drawn = math.sqrt((hx - lx) ^ 2 + (hz - lz) ^ 2)
		local ux, uz = (hx - lx) / drawn, (hz - lz) / drawn
		local width = math.sqrt((h2[1] - h1[1]) ^ 2 + (h2[2] - h1[2]) ^ 2)
		local total = drawn + entry.extend
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
				ramp = index,
				firstHill = entry.firstHill,
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

-- Where a plant at (x, z) in a tunnel or the cave gets out: walks the
-- tunnel outward in a grid of `tunnelExitStep` squares to the nearest
-- open ground (not tunnel, no rock or ramp, not river), then goes
-- `tunnelExitMargin` further the same way if that is open too. Returns
-- nil when (x, z) isn't in a tunnel or no way out is found.
function MapRules.tunnelExit(map: any, hills: any, x: number, z: number): (number?, number?)
	if not MapRules.inTunnel(map, hills, x, z) then
		return nil, nil
	end
	local config = map.Hills
	local step = config.tunnelExitStep
	local limit = math.ceil(config.tunnelExitReach / step)
	local function open(px: number, pz: number): boolean
		return not MapRules.inTunnel(map, hills, px, pz)
			and MapRules.hillsHeight(map, hills, px, pz) == 0
			and not MapRules.inRiver(map, px, pz)
	end
	local seen = { ["0,0"] = true }
	local queue = { { 0, 0 } }
	local head = 1
	while head <= #queue do
		local i, j = queue[head][1], queue[head][2]
		head += 1
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ni, nj = i + d[1], j + d[2]
			local key = `{ni},{nj}`
			if not seen[key] and math.abs(ni) <= limit and math.abs(nj) <= limit then
				seen[key] = true
				local px, pz = x + ni * step, z + nj * step
				if open(px, pz) then
					local fx = px + d[1] * config.tunnelExitMargin
					local fz = pz + d[2] * config.tunnelExitMargin
					if open(fx, fz) then
						return fx, fz
					end
					return px, pz
				elseif MapRules.inTunnel(map, hills, px, pz) then
					table.insert(queue, { ni, nj })
				end
			end
		end
	end
	return nil, nil
end

-- The terrain rock at a point on a rise: from `bottom` to `top` above the
-- ground, and the rise. Over a tunnel or the cave the rock starts above
-- the arched roof (bottom > 0), and may be empty when the roof parts reach
-- the top. Ramps are parts, so no rock there. The bottom left hill is
-- First Rise rock, except near its tunnel, which is parts: no terrain cell
-- (`terrainCell` square, middle at x, z) reaches into the tunnel, and the
-- walls cover up to the nearest rock.
function MapRules.hillsRock(map: any, hills: any, x: number, z: number): (number, number, number)
	if MapRules.rampAt(map, hills, x, z) ~= nil then
		return 0, 0, 0
	end
	local config = map.Hills
	local ridge = hills.ridge
	local _, along, across = MapRules.ridgeOffset(hills, x, z)
	local cellReach = config.terrainCell / 2 * (math.abs(ridge.dx) + math.abs(ridge.dz))
	if
		math.abs(along) <= ridge.length / 2 + cellReach
		and math.abs(across) < MapRules.ridgeBandHalf(map) - cellReach
	then
		return 0, 0, 0
	end
	if MapRules.inPolygon(config.firstHill.outline, x, z) then
		return 0, config.riseHeights[1], 1
	end
	local layer = MapRules.hillsLayer(hills, x, z)
	if layer == 0 then
		return 0, 0, 0
	end
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

-- Height of the walkable surface above the ground at a point.
function MapRules.hillsHeight(map: any, hills: any, x: number, z: number): number
	local ramp = MapRules.rampAt(map, hills, x, z)
	if ramp then
		return ramp
	end
	if MapRules.onFirstHill(map, hills, x, z) then
		return map.Hills.riseHeights[1]
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

-- Where the cave lanterns go: `caveLanternsPerWall` on each of the
-- cave's two long walls, spread along its length. Each spot is the face of
-- the wall (the edge of the first solid terrain cell, from `grid`) and the
-- direction facing into the cave: { x, z, nx, nz }.
function MapRules.caveLanternSpots(map: any, hills: any, grid: { { { number } } }): { { number } }
	local config = map.Hills
	local cell = config.terrainCell
	local count = #grid
	local spots = {}
	local function wallAt(x: number, z: number): boolean
		local i, j = math.floor(x / cell) + 1, math.floor(-z / cell) + 1
		if i < 1 or j < 1 or i > count or j > count then
			return true
		end
		return MapRules.isWallCell(grid[j][i])
	end
	for _, room in hills.caveRooms do
		-- Middle and long direction of the cave (from its corners).
		local cx, cz = 0, 0
		for _, corner in room do
			cx += corner[1] / #room
			cz += corner[2] / #room
		end
		local sxx, sxz, szz = 0, 0, 0
		for _, corner in room do
			local dx, dz = corner[1] - cx, corner[2] - cz
			sxx += dx * dx
			sxz += dx * dz
			szz += dz * dz
		end
		local angle = 0.5 * math.atan2(2 * sxz, sxx - szz)
		local ax, az = math.cos(angle), math.sin(angle)
		local low, high = math.huge, -math.huge
		for _, corner in room do
			local along = (corner[1] - cx) * ax + (corner[2] - cz) * az
			low, high = math.min(low, along), math.max(high, along)
		end
		local perWall = config.caveLanternsPerWall
		for _, side in { -1, 1 } do
			-- Across the cave: (-az, ax) one way, (az, -ax) the other.
			local px, pz = -az * side, ax * side
			for n = 1, perWall do
				local along = low + (high - low) * n / (perWall + 1)
				local x, z = cx + ax * along, cz + az * along
				local travelled = 0
				while travelled < 60 and not wallAt(x + px * 0.25, z + pz * 0.25) do
					x, z = x + px * 0.25, z + pz * 0.25
					travelled += 0.25
				end
				if travelled < 60 then
					table.insert(spots, { x, z, -px, -pz })
				end
			end
		end
	end
	return spots
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
		if
			MapRules.rampAt(map, hills, x, z) == nil and not MapRules.onFirstHill(map, hills, x, z)
		then
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

-- May a creature spawn in `area` when it belongs in `home` (from
-- `creatureArea`)? Land creatures may also spawn on the First Rise.
function MapRules.spawnAllowed(home: string, area: string): boolean
	return area == home or (home == "Land" and area == "FirstRise")
end

-- May a creature that belongs in `home` wander into `area`? As for
-- spawning, except tunnel creatures (bats) may wander out of the tunnels
-- onto the land and the First Rise.
function MapRules.creatureAllowed(home: string, area: string): boolean
	if home == "Tunnel" and (area == "Land" or area == "FirstRise") then
		return true
	end
	return MapRules.spawnAllowed(home, area)
end

-- Where the grass clumps stand in a hiding grass `circle` ({ x, z,
-- radius }): a staggered grid `clumpSpacing` apart, each spot moved up to
-- `clumpSpread` by `random` (0 to 1), none closer than `clumpEdgeMargin` to
-- the edge. Returns a list of { x, z }.
function MapRules.grassClumpSpots(map: any, circle: any, random: () -> number): { { number } }
	local grass = map.HidingGrass
	local spacing = grass.clumpSpacing
	local spread = grass.clumpSpread
	local limit = circle.radius - grass.clumpEdgeMargin
	local spots = {}
	local row = 0
	local across = -circle.radius
	while across <= circle.radius do
		local along = -circle.radius + (if row % 2 == 0 then 0 else spacing / 2)
		while along <= circle.radius do
			local dx = along + (random() * 2 - 1) * spread
			local dz = across + (random() * 2 - 1) * spread
			if dx * dx + dz * dz <= limit * limit then
				table.insert(spots, { circle.x + dx, circle.z + dz })
			end
			along += spacing
		end
		across += spacing * 0.87
		row += 1
	end
	return spots
end

-- Whether the Grassland's terrain grass may cover (x, z): not in or near
-- a grass circle or a cow pen (the safe field is the builder's to skip).
function MapRules.grasslandGrassGround(map: any, x: number, z: number): boolean
	local land = map.Grassland
	for _, circle in land.grassCircles do
		local reach = circle.radius + land.groundCircleMargin
		if (x - circle.x) ^ 2 + (z - circle.z) ^ 2 <= reach * reach then
			return false
		end
	end
	for _, field in land.cowFields do
		local half = field.size / 2 + land.groundPenMargin
		if math.abs(x - field.x) <= half and math.abs(z - field.z) <= half then
			return false
		end
	end
	return true
end

function MapRules.inHidingGrass(map: any, x: number, z: number): boolean
	for _, list in { map.HidingGrass.circles, map.Grassland.grassCircles } do
		for _, circle in list do
			if (x - circle.x) ^ 2 + (z - circle.z) ^ 2 <= circle.radius ^ 2 then
				return true
			end
		end
	end
	return false
end

-- Whether terrain grass stays off (x, z): in or near the river, or in or
-- near a hiding grass patch, so it doesn't cover either.
function MapRules.keepGrassGroundOff(map: any, x: number, z: number): boolean
	local river = map.River
	local distance = MapRules.closestOnLine(river.centreLine, x, z)
	if distance <= river.width / 2 + river.groundRiverMargin then
		return true
	end
	if MapRules.inPolygon(map.Marsh.outline, x, z) then
		return true
	end
	local outline = map.Marsh.outline
	local closed = table.clone(outline)
	table.insert(closed, outline[1])
	if MapRules.closestOnLine(closed, x, z) <= river.groundMarshMargin then
		return true
	end
	local reach = river.groundHidingGrassMargin
	for _, circle in map.HidingGrass.circles do
		if (x - circle.x) ^ 2 + (z - circle.z) ^ 2 <= (circle.radius + reach) ^ 2 then
			return true
		end
	end
	return false
end

-- Where the water lily for pad `index` of `layout` grows: beside the pad
-- (radius `padRadius`), out of eight directions the one furthest from the
-- other pads, keeping to the marsh where it can.
function MapRules.lilyFlowerSpot(
	map: any,
	layout: { { number } },
	index: number,
	padRadius: number
): (number, number)
	local pads = map.LilyPads
	local pad = layout[index]
	local reach = padRadius + pads.flowerOffset
	local bestX, bestZ, bestScore = pad[1] + reach, pad[2], -math.huge
	for step = 0, 7 do
		local angle = step * math.pi / 4
		local x = pad[1] + math.cos(angle) * reach
		local z = pad[2] + math.sin(angle) * reach
		local clearance = math.huge
		for other, spot in layout do
			if other ~= index then
				clearance = math.min(clearance, math.sqrt((spot[1] - x) ^ 2 + (spot[2] - z) ^ 2))
			end
		end
		local score = clearance + (MapRules.inMarsh(map, x, z) and 1000 or 0)
		if score > bestScore then
			bestX, bestZ, bestScore = x, z, score
		end
	end
	return bestX, bestZ
end

-- Where the reeds go along the river banks: a list of { x, z, count },
-- count 0 for a clump (the builder picks its size) and 1 for a single
-- reed. The same every time.
function MapRules.riverReedSpots(map: any): { { number } }
	local reeds = map.RiverReeds
	local river = map.River
	local line = river.centreLine
	local seed = reeds.layoutSeed
	local function random(): number
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
	local limit = map.halfSize - map.edgeMargin
	local crossings = {
		{ map.MoonBridge.x, map.MoonBridge.z, map.MoonBridge.width / 2 },
		{ map.RopeBridge.x, map.RopeBridge.z, map.RopeBridge.width / 2 },
		{ map.Ford.x, map.Ford.z, map.Ford.rows * map.Ford.spacing },
	}
	local function clear(x: number, z: number): boolean
		if math.abs(x) > limit or math.abs(z) > limit then
			return false
		end
		-- The far banks are the Hills' and the Forest's edges.
		if MapRules.territoryAt(map, x, z) == "Field" then
			return false
		end
		local pathDistance = MapRules.closestOnLine(map.Path.centreLine, x, z)
		if pathDistance <= map.Path.width / 2 + reeds.crossingClear then
			return false
		end
		for _, crossing in crossings do
			-- Distance along the river from the crossing's middle line.
			local _, dx, dz = MapRules.closestOnLine(line, crossing[1], crossing[2])
			local along = math.abs((x - crossing[1]) * dx + (z - crossing[2]) * dz)
			local across = math.abs((x - crossing[1]) * dz - (z - crossing[2]) * dx)
			if along <= crossing[3] + reeds.crossingClear and across <= river.width then
				return false
			end
		end
		return true
	end
	local spots = {}
	local function place(distance: number, side: number, count: number)
		-- Walk `distance` along the line to find the point and direction.
		local left = distance
		for i = 1, #line - 1 do
			local ax, az = line[i][1], line[i][2]
			local sx, sz = line[i + 1][1] - ax, line[i + 1][2] - az
			local length = math.sqrt(sx * sx + sz * sz)
			if left <= length then
				local dx, dz = sx / length, sz / length
				local out = river.width / 2
					+ reeds.bankOffset[1]
					+ random() * (reeds.bankOffset[2] - reeds.bankOffset[1])
				local x = ax + dx * left - dz * side * out
				local z = az + dz * left + dx * side * out
				-- At a bend the far side of the line may be closer.
				local nearest = MapRules.closestOnLine(line, x, z)
				if nearest > river.width / 2 and clear(x, z) then
					table.insert(spots, { x, z, count })
				end
				return
			end
			left -= length
		end
	end
	local total = 0
	for i = 1, #line - 1 do
		total += math.sqrt((line[i + 1][1] - line[i][1]) ^ 2 + (line[i + 1][2] - line[i][2]) ^ 2)
	end
	for _, side in { -1, 1 } do
		local distance = reeds.clumpSpacing / 2
		while distance < total do
			place(distance + (random() * 2 - 1) * reeds.clumpJitter, side, 0)
			for _ = 1, reeds.singlesBetween do
				place(distance + random() * reeds.clumpSpacing, side, 1)
			end
			distance += reeds.clumpSpacing
		end
	end
	return spots
end

-- Where the path lights stand: `count` spots evenly spaced along the path
-- with one gap in from each end, on the side away from the marsh. Returns
-- a list of { x, z }.
function MapRules.pathLightSpots(map: any): { { number } }
	local lights = map.PathLights
	local line = map.Path.centreLine
	local total = 0
	for i = 1, #line - 1 do
		total += math.sqrt((line[i + 1][1] - line[i][1]) ^ 2 + (line[i + 1][2] - line[i][2]) ^ 2)
	end
	local out = map.Path.width / 2 + lights.edgeOffset
	local marsh = table.clone(map.Marsh.outline)
	table.insert(marsh, map.Marsh.outline[1])
	local spots = {}
	for n = 1, lights.count do
		local left = total * n / (lights.count + 1)
		for i = 1, #line - 1 do
			local ax, az = line[i][1], line[i][2]
			local sx, sz = line[i + 1][1] - ax, line[i + 1][2] - az
			local length = math.sqrt(sx * sx + sz * sz)
			if left <= length then
				local dx, dz = sx / length, sz / length
				local px, pz = ax + dx * left, az + dz * left
				local best, bestScore = nil, -math.huge
				for _, side in { -1, 1 } do
					local x, z = px - dz * side * out, pz + dx * side * out
					local score = MapRules.closestOnLine(marsh, x, z)
					if MapRules.inPolygon(map.Marsh.outline, x, z) then
						score = -score
					end
					if score > bestScore then
						best, bestScore = { x, z }, score
					end
				end
				table.insert(spots, best)
				break
			end
			left -= length
		end
	end
	return spots
end

-- How far a grass blade at (x, z) leans at time `now` (radians): a
-- gentle sway that moves across the grass like wind.
function MapRules.grassWave(map: any, now: number, x: number, z: number): number
	local grass = map.HidingGrass
	local turn = now / grass.waveSeconds + (x + z * 0.6) * grass.waveSpread
	return math.rad(grass.waveDegrees) * math.sin(turn * math.pi * 2)
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

-- How much of the full sway a rope bridge piece `offset` studs along the
-- bridge from its middle gets: 1 at the middle, 0 at the ends (tied to the
-- posts), on a smooth curve.
function MapRules.ropeBridgeSwayShare(map: any, offset: number): number
	local share = math.clamp(offset / (map.RopeBridge.length / 2), -1, 1)
	return math.cos(share * math.pi / 2)
end

-- The rope bridge's swing each way at the middle, in degrees, so the deck
-- there moves `swayStuds` sideways.
function MapRules.ropeBridgeSwayDegrees(map: any): number
	local bridge = map.RopeBridge
	return math.deg(math.atan(bridge.swayStuds / bridge.swayPivotHeight))
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

-- A random point in a territory where a creature from `home` may spawn
-- (see `spawnAllowed`). Falls back to any point in the territory if none is
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
		if MapRules.spawnAllowed(home, MapRules.areaAt(map, x, z, hills)) then
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
