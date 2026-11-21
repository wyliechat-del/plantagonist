--[[
	Targeting: bites go where the player clicks or taps.

	A candidate is { key = any, x, y, z, radius }. Distances to a candidate
	are measured to its edge, so big targets are easier to reach and to hit.
]]

local Aim = {}

export type Candidate = { key: any, x: number, y: number, z: number, radius: number }
export type Point = { x: number, y: number, z: number }

-- Gap from a point to the candidate's edge (0 when inside it).
function Aim.gap(candidate: Candidate, from: Point): number
	local dx, dy, dz = candidate.x - from.x, candidate.y - from.y, candidate.z - from.z
	return math.max(0, math.sqrt(dx * dx + dy * dy + dz * dz) - candidate.radius)
end

-- The candidate under a click: the one closest to the ray from `origin`
-- along the unit vector `direction`, within `slack` studs of the ray, and
-- within `reach` of the plant at `from`. Ties go to the nearer one.
function Aim.pickOnRay(
	candidates: { Candidate },
	origin: Point,
	direction: Point,
	from: Point,
	reach: number,
	slack: number
): Candidate?
	local best: Candidate? = nil
	local bestOff, bestAlong = math.huge, math.huge
	for _, candidate in candidates do
		if Aim.gap(candidate, from) <= reach then
			local cx, cy, cz =
				candidate.x - origin.x, candidate.y - origin.y, candidate.z - origin.z
			local along = cx * direction.x + cy * direction.y + cz * direction.z
			if along > 0 then
				local px = cx - direction.x * along
				local py = cy - direction.y * along
				local pz = cz - direction.z * along
				local off = math.max(0, math.sqrt(px * px + py * py + pz * pz) - candidate.radius)
				if off <= slack and (off < bestOff or (off == bestOff and along < bestAlong)) then
					best, bestOff, bestAlong = candidate, off, along
				end
			end
		end
	end
	return best
end

-- The nearest candidate within `reach` of `from` (phones highlight this one,
-- since there is no mouse to hover with).
function Aim.nearest(candidates: { Candidate }, from: Point, reach: number): Candidate?
	local best: Candidate? = nil
	local bestGap = math.huge
	for _, candidate in candidates do
		local gap = Aim.gap(candidate, from)
		if gap <= reach and gap < bestGap then
			best, bestGap = candidate, gap
		end
	end
	return best
end

-- Where a miss lands: the clicked point, pulled in to `reach` from the plant
-- (flat distance), so a snap at the air happens in front of the plant.
function Aim.missPoint(from: Point, point: Point, reach: number): Point
	local dx, dz = point.x - from.x, point.z - from.z
	local flat = math.sqrt(dx * dx + dz * dz)
	if flat <= reach or flat < 0.001 then
		return point
	end
	local scale = reach / flat
	return { x = from.x + dx * scale, y = point.y, z = from.z + dz * scale }
end

return table.freeze(Aim)
