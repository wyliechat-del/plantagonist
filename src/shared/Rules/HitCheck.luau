--[[
	Server-side checks that a bite or power up use is possible, so exploiters
	can't bite from across the map.
]]

local HitCheck = {}

-- Distance between the edges of two round things (centres in studs).
function HitCheck.gap(
	ax: number,
	ay: number,
	az: number,
	aRadius: number,
	bx: number,
	by: number,
	bz: number,
	bRadius: number
): number
	local dx, dy, dz = ax - bx, ay - by, az - bz
	return math.sqrt(dx * dx + dy * dy + dz * dz) - aRadius - bRadius
end

-- Can something `gap` studs away be reached by a reach of `reach`, allowing
-- `tolerance` extra studs for network lag?
function HitCheck.inReach(gap: number, reach: number, tolerance: number): boolean
	return gap <= reach + tolerance
end

return table.freeze(HitCheck)
