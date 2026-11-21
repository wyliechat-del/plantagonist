--[[
	Simple movement for creatures and NPC plants, on plain X and Z numbers.
]]

local Steering = {}

-- Moves (x, z) towards (tx, tz) by at most `step` studs. Returns the new
-- point and whether it arrived.
function Steering.moveTowards(
	x: number,
	z: number,
	tx: number,
	tz: number,
	step: number
): (number, number, boolean)
	local dx, dz = tx - x, tz - z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance <= step or distance < 0.001 then
		return tx, tz, true
	end
	return x + dx / distance * step, z + dz / distance * step, false
end

-- The direction (unit X, Z) away from the nearest threat, or nil when no
-- threat is within `fleeDistance`. Threats are { x, z }.
function Steering.fleeDirection(
	x: number,
	z: number,
	threats: { { x: number, z: number } },
	fleeDistance: number
): (number?, number?)
	local nearest, nearestDistance = nil, fleeDistance
	for _, threat in threats do
		local dx, dz = x - threat.x, z - threat.z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance < nearestDistance then
			nearest, nearestDistance = threat, distance
		end
	end
	if nearest == nil then
		return nil, nil
	end
	local dx, dz = x - nearest.x, z - nearest.z
	if nearestDistance < 0.001 then
		return 1, 0
	end
	return dx / nearestDistance, dz / nearestDistance
end

-- A last-moment dodge away from a threat at (tx, tz): mostly sideways, a
-- little away. `side` is 1 or -1. Returns a unit X, Z direction.
function Steering.dodgeDirection(
	x: number,
	z: number,
	tx: number,
	tz: number,
	side: number
): (number, number)
	local ax, az = x - tx, z - tz
	local length = math.sqrt(ax * ax + az * az)
	if length < 0.001 then
		ax, az, length = 1, 0, 1
	end
	ax, az = ax / length, az / length
	-- Sideways is the away direction turned a quarter turn.
	local dx, dz = -az * side * 0.8 + ax * 0.6, ax * side * 0.8 + az * 0.6
	local size = math.sqrt(dx * dx + dz * dz)
	return dx / size, dz / size
end

-- A wander target within `radius` of (x, z). `random()` returns [0, 1).
function Steering.wanderTarget(
	x: number,
	z: number,
	radius: number,
	random: () -> number
): (number, number)
	local angle = random() * math.pi * 2
	local distance = radius * (0.3 + 0.7 * random())
	return x + math.cos(angle) * distance, z + math.sin(angle) * distance
end

-- Height of a bobbing creature at time `t`.
function Steering.bob(t: number, phase: number, height: number): number
	return math.abs(math.sin(t * 3 + phase)) * height
end

-- Height of a fright hop `elapsed` seconds after it started: up and back
-- down over `seconds`, 0 before and after.
function Steering.hop(elapsed: number, seconds: number, height: number): number
	if elapsed <= 0 or elapsed >= seconds then
		return 0
	end
	return height * math.sin(math.pi * elapsed / seconds)
end

return table.freeze(Steering)
