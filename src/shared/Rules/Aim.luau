--[[
	Aim assist: picks the target nearest the crosshair.

	A candidate is { key = any, x, y, z, radius }. The camera looks from
	(ox, oy, oz) along the unit vector (dx, dy, dz). Candidates further than
	`maxDistance` (measured from `from`, the plant) or more than `maxDegrees`
	off the camera's line are skipped. The best target has the smallest angle,
	with a small bonus for being close.
]]

local Aim = {}

export type Candidate = { key: any, x: number, y: number, z: number, radius: number }
export type Point = { x: number, y: number, z: number }

function Aim.pick(
	candidates: { Candidate },
	camera: Point,
	look: Point,
	from: Point,
	maxDistance: number,
	maxDegrees: number
): Candidate?
	local best: Candidate? = nil
	local bestScore = math.huge
	local maxRadians = math.rad(maxDegrees)
	for _, candidate in candidates do
		local fx, fy, fz = candidate.x - from.x, candidate.y - from.y, candidate.z - from.z
		local distanceFromPlant = math.sqrt(fx * fx + fy * fy + fz * fz) - candidate.radius
		if distanceFromPlant <= maxDistance then
			local cx, cy, cz =
				candidate.x - camera.x, candidate.y - camera.y, candidate.z - camera.z
			local length = math.sqrt(cx * cx + cy * cy + cz * cz)
			if length > 0.001 then
				local dot = (cx * look.x + cy * look.y + cz * look.z) / length
				local angle = math.acos(math.clamp(dot, -1, 1))
				-- Big targets are easier to hit: allow their angular size.
				local slack = math.atan(candidate.radius / length)
				if angle - slack <= maxRadians then
					local score = math.max(angle - slack, 0)
						+ distanceFromPlant / math.max(maxDistance, 1) * 0.2
					if score < bestScore then
						best, bestScore = candidate, score
					end
				end
			end
		end
	end
	return best
end

return table.freeze(Aim)
