local HillsShape = require("../src/shared/Config/HillsShape")
local Map = require("../src/shared/Config/Map")
local Plants = require("../src/shared/Config/Plants")
local MapRules = require("../src/shared/Rules/Map")

return function(t)
	t.test("territories are the four quarters, the field is the middle", function()
		t.expectEqual(MapRules.territoryAt(Map, 200, 200), "Grassland")
		t.expectEqual(MapRules.territoryAt(Map, -200, 200), "Forest")
		t.expectEqual(MapRules.territoryAt(Map, -200, -200), "River")
		t.expectEqual(MapRules.territoryAt(Map, 200, -200), "Hills")
		t.expectEqual(MapRules.territoryAt(Map, 10, -10), "Field")
	end)

	t.test("only levels 1 and 2 may be in the field", function()
		t.expect(MapRules.canBeInField(Map, 2))
		t.expect(not MapRules.canBeInField(Map, 3))
		local x, z = MapRules.pushOut(Map, 30, 40)
		local distance = MapRules.distanceFromCentre(x, z)
		t.expectEqual(math.floor(distance + 0.5), Map.Field.radius + Map.Field.pushOutMargin)
	end)

	t.test("12 exits, 3 per territory", function()
		local angles = MapRules.exitAngles(Map)
		t.expectEqual(#angles, 12)
		t.expect(MapRules.isExitAngle(Map, 45))
		t.expect(MapRules.isExitAngle(Map, 45 + 360))
		t.expect(not MapRules.isExitAngle(Map, 0))
	end)

	t.test("river slows everyone; marsh slows only levels 4 to 6; crossings don't slow", function()
		local rx, rz = Map.River.centreLine[5][1], Map.River.centreLine[5][2]
		t.expectEqual(MapRules.areaAt(Map, rx, rz), "Water")
		t.expectEqual(MapRules.speedFactor(Map, 1, rx, rz, false), Map.River.speedFactor)
		t.expectEqual(MapRules.speedFactor(Map, 6, rx, rz, true), 1, "on a bridge")
		local pad = Map.LilyPads.positions[1]
		t.expectEqual(MapRules.areaAt(Map, pad[1], pad[2]), "Marsh")
		t.expectEqual(MapRules.speedFactor(Map, 3, pad[1], pad[2], false), 1)
		t.expectEqual(MapRules.speedFactor(Map, 4, pad[1], pad[2], false), Map.Marsh.speedFactor)
		t.expectEqual(MapRules.speedFactor(Map, 6, pad[1], pad[2], true), 1, "on a lily pad")
		t.expectEqual(MapRules.speedFactor(Map, 6, -300, -200, false), 1, "green land")
		local path = Map.Path.centreLine[4]
		t.expectEqual(MapRules.speedFactor(Map, 6, path[1], path[2], false), 1, "the path")
	end)

	t.test("all lily pads sit on the marsh, and the river stays in the River quarter", function()
		for _, pad in Map.LilyPads.positions do
			t.expect(MapRules.inMarsh(Map, pad[1], pad[2]), `pad at {pad[1]}, {pad[2]}`)
		end
		for _, point in MapRules.pointsAlong(Map.River.centreLine, 5, 0) do
			local x, z = point[1], point[2]
			if math.abs(x) < Map.halfSize and math.abs(z) < Map.halfSize then
				t.expect(
					x + Map.River.width / 2 <= 0 and z + Map.River.width / 2 <= 0,
					`river at {x}, {z}`
				)
				local clear = MapRules.distanceFromCentre(x, z) - Map.River.width / 2
				t.expect(clear > Map.Field.radius + 10, "river clear of the safe field")
			end
		end
	end)

	t.test("crossings sit on the river and the path starts at the moon bridge", function()
		for _, crossing in { Map.MoonBridge, Map.RopeBridge, Map.Ford } do
			t.expect(MapRules.inRiver(Map, crossing.x, crossing.z), "crossing over water")
		end
		local _, dx, dz =
			MapRules.closestOnLine(Map.River.centreLine, Map.MoonBridge.x, Map.MoonBridge.z)
		local first = Map.Path.centreLine[1]
		local ex, ez =
			Map.MoonBridge.x - dz * Map.MoonBridge.span / 2,
			Map.MoonBridge.z + dx * Map.MoonBridge.span / 2
		local fx, fz =
			Map.MoonBridge.x + dz * Map.MoonBridge.span / 2,
			Map.MoonBridge.z - dx * Map.MoonBridge.span / 2
		local nearest = math.min(
			math.sqrt((ex - first[1]) ^ 2 + (ez - first[2]) ^ 2),
			math.sqrt((fx - first[1]) ^ 2 + (fz - first[2]) ^ 2)
		)
		t.expect(nearest < 6, `path starts {nearest} studs from a bridge end`)
		local last = Map.Path.centreLine[#Map.Path.centreLine]
		t.expect(math.abs(last[1] - Map.Gate.x) < 1, "path ends at the gate")
	end)

	t.test("moon bridge: levels 1 to 4 fit under the middle with room to spare", function()
		local bridge = Map.MoonBridge
		local height = Plants.heightAtScale1 * Plants.scaleByLevel[bridge.passUnderMaxLevel]
		local radius = Plants.radiusAtScale1 * Plants.scaleByLevel[bridge.passUnderMaxLevel]
		for _, offset in { 0, radius * 2 } do
			local underside = MapRules.moonBridgeHeight(Map, offset) - bridge.thickness
			t.expect(
				height + bridge.headroom < underside,
				`level 4 fits {offset} studs off the middle`
			)
		end
		t.expectEqual(MapRules.moonBridgeHeight(Map, bridge.span / 2), 0, "meets the bank")
		-- Not steeper than a plant can walk.
		local slope = 4 * bridge.rise / bridge.span
		t.expect(math.deg(math.atan(slope)) < 50, "walkable slope")
	end)

	t.test("rope bridge and ford rocks stay above the water", function()
		t.expect(MapRules.ropeBridgeHeight(Map, 0) > Map.River.depth, "rope bridge middle")
		t.expect(Map.Ford.minTop > Map.River.depth, "ford rocks")
	end)

	t.test("frog hop: launch speed reaches the hop height", function()
		local gravity = 196.2
		local speed = MapRules.hopLaunchSpeed(gravity, Map.LilyPads.hopHeight)
		t.expect(math.abs(speed * speed / (2 * gravity) - Map.LilyPads.hopHeight) < 1e-6)
	end)

	t.test("three times the lily pads, all on the marsh and not overlapping", function()
		local pads = MapRules.lilyPadLayout(Map)
		t.expectEqual(#pads, #Map.LilyPads.positions * (1 + Map.LilyPads.extraPadsPer))
		local minGap = Map.LilyPads.size * (1 + Map.LilyPads.sizeVariation)
		for i, pad in pads do
			t.expect(MapRules.inMarsh(Map, pad[1], pad[2]), "on the marsh")
			for j = i + 1, #pads do
				local other = pads[j]
				t.expect(
					math.sqrt((pad[1] - other[1]) ^ 2 + (pad[2] - other[2]) ^ 2) >= minGap,
					"no overlap"
				)
			end
		end
		t.expectEqual(MapRules.lilyPadLayout(Map)[30][1], pads[30][1], "same layout every time")
	end)

	t.test("grass blades: tall enough to hide in, waving only a little", function()
		local grass = Map.HidingGrass
		local visible = grass.height * grass.sizeRange[2] * (1 - grass.bladeSunk)
		t.expect(visible >= grass.height * 0.85, "the biggest blades stand near the grass height")
		t.expect(grass.sizeRange[1] < 1 and grass.sizeRange[2] > 1, "sizes go both ways")
		t.expectEqual(#grass.bladeColours, 3)
		local most = 0
		for step = 0, 100 do
			local lean = MapRules.grassWave(Map, step * 0.1, step * 3, -step * 2)
			most = math.max(most, math.abs(lean))
		end
		t.expect(most <= math.rad(grass.waveDegrees) + 1e-9, "never leans past waveDegrees")
		t.expect(most > 0, "it waves")
		t.expect(
			MapRules.grassWave(Map, 1, 0, 0) ~= MapRules.grassWave(Map, 1, 20, 0),
			"blades apart lean differently"
		)
	end)

	t.test("terrain grass stays off the river and the hiding grass", function()
		local river = Map.River
		local point = river.centreLine[3]
		t.expect(MapRules.keepGrassGroundOff(Map, point[1], point[2]), "off the river")
		local patch = Map.HidingGrass.circles[1]
		local reach = patch.radius + river.groundHidingGrassMargin - 0.5
		t.expect(MapRules.keepGrassGroundOff(Map, patch.x + reach, patch.z), "round a patch")
		local corner = Map.Marsh.outline[1]
		t.expect(MapRules.keepGrassGroundOff(Map, corner[1] - 2, corner[2]), "off the marsh edge")
		t.expect(not MapRules.keepGrassGroundOff(Map, -400, -20), "grass elsewhere")
	end)

	t.test("river reeds: on both banks, out of the water, off the crossings", function()
		local spots = MapRules.riverReedSpots(Map)
		local clumps, singles = 0, 0
		local sides = {}
		for _, spot in spots do
			local x, z = spot[1], spot[2]
			t.expect(not MapRules.inRiver(Map, x, z), "not in the water")
			t.expect(not MapRules.onPath(Map, x, z), "not on the path")
			t.expect(MapRules.territoryAt(Map, x, z) ~= "Field", "not in the safe field")
			if MapRules.territoryAt(Map, x, z) == "Hills" then
				t.expectEqual(MapRules.hillsHeight(Map, HillsShape, x, z), 0, "on flat ground")
			end
			if spot[3] == 0 then
				clumps += 1
			else
				singles += 1
			end
			-- The last stretch runs straight along z = -21.
			if x < -275 then
				sides[if z > -21 then 1 else 2] = true
			end
		end
		t.expect(clumps >= 10 and singles >= 10, "clumps with singles between")
		t.expect(sides[1] and sides[2], "both banks")
		local bridge = Map.MoonBridge
		for _, spot in spots do
			local near = (spot[1] - bridge.x) ^ 2 + (spot[2] - bridge.z) ^ 2
				< (bridge.width / 2) ^ 2
			t.expect(not near, "clear of the moon bridge")
		end
	end)

	t.test("path lights: evenly spaced beside the path, on the grass side", function()
		local spots = MapRules.pathLightSpots(Map)
		t.expectEqual(#spots, Map.PathLights.count)
		for _, spot in spots do
			local distance = MapRules.closestOnLine(Map.Path.centreLine, spot[1], spot[2])
			t.expect(distance > Map.Path.width / 2, "off the path")
			t.expect(
				not MapRules.inPolygon(Map.Marsh.outline, spot[1], spot[2]),
				"not in the marsh"
			)
		end
		local first, last = spots[1], spots[#spots]
		local gate = Map.Path.centreLine[#Map.Path.centreLine]
		local away = function(a, b)
			return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
		end
		t.expect(away(first, Map.Path.centreLine[1]) > 20, "one gap in from the bridge end")
		t.expect(away(last, gate) > 20, "one gap in from the gates")
	end)

	t.test("water lilies grow beside their pads, not on them", function()
		local layout = MapRules.lilyPadLayout(Map)
		local pads = Map.LilyPads
		local radius = pads.size / 2
		for index = 1, pads.lilyFlowers do
			local x, z = MapRules.lilyFlowerSpot(Map, layout, index, radius)
			local pad = layout[index]
			local away = math.sqrt((x - pad[1]) ^ 2 + (z - pad[2]) ^ 2)
			t.expect(math.abs(away - radius - pads.flowerOffset) < 1e-6, "beside its own pad")
		end
	end)

	t.test("hiding grass hides levels 1 to 3 until they attack", function()
		local circle = Map.HidingGrass.circles[1]
		t.expect(MapRules.hiddenInGrass(Map, 3, circle.x, circle.z, 10, 0))
		t.expect(not MapRules.hiddenInGrass(Map, 4, circle.x, circle.z, 10, 0), "too big")
		t.expect(not MapRules.hiddenInGrass(Map, 1, circle.x, circle.z, 10, 12), "just attacked")
		t.expect(not MapRules.hiddenInGrass(Map, 1, 0, 0, 10, 0), "not in grass")
	end)

	t.test(
		"native blowfish spawn in the river, native toads in the marsh, others on land",
		function()
			t.expectEqual(MapRules.creatureArea(Map, "blowfish", true), "Water")
			t.expectEqual(MapRules.creatureArea(Map, "toad", true), "Marsh")
			t.expectEqual(MapRules.creatureArea(Map, "toad", false), "Land")
			t.expectEqual(MapRules.creatureArea(Map, "eel", true), "Land")
			local seed = 1
			local function random()
				seed = (seed * 16807 + 12345) % 2147483647
				return seed / 2147483647
			end
			for _, area in { "Water", "Marsh", "Land" } do
				for _ = 1, 20 do
					local x, z = MapRules.randomPointInArea(Map, "River", area, random)
					t.expectEqual(MapRules.areaAt(Map, x, z), area)
					t.expectEqual(MapRules.territoryAt(Map, x, z), "River")
				end
			end
		end
	)

	t.test("random points stay in their territory", function()
		local seed = 0
		local function random()
			seed = (seed * 16807 + 12345) % 2147483647
			return seed / 2147483647
		end
		for _, name in { "Grassland", "Forest", "River", "Hills" } do
			for _ = 1, 50 do
				local x, z = MapRules.randomPointIn(Map, name, random)
				t.expectEqual(MapRules.territoryAt(Map, x, z), name)
			end
		end
		local x, z = MapRules.clampToTerritory(Map, "Hills", -50, 900)
		t.expectEqual(MapRules.territoryAt(Map, x, z), "Hills")
	end)

	local function plantHeight(level)
		return Plants.heightAtScale1 * Plants.scaleByLevel[level]
	end

	t.test("tunnels fit levels 1 to 3 under the arch, logs fit levels 1 and 2", function()
		local hills = Map.Hills
		t.expect(plantHeight(3) < hills.tunnelClearance, "level 3 fits a tunnel")
		t.expect(plantHeight(4) > hills.tunnelClearance, "level 4 doesn't")
		-- Level 3 still fits with its side against the wall.
		local radius = Plants.radiusAtScale1 * Plants.scaleByLevel[3]
		local atSide = MapRules.archHeight(
			hills.tunnelWallHeight,
			hills.tunnelClearance,
			hills.tunnelArchReach,
			radius
		)
		t.expect(atSide > plantHeight(3), "level 3 fits beside the wall")
		t.expectEqual(MapRules.archHeight(7, 10, 6, 0), 7)
		t.expectEqual(MapRules.archHeight(7, 10, 6, 6), 10)
		t.expectEqual(MapRules.archHeight(7, 10, 6, 20), 10)
		t.expect(plantHeight(2) < Map.Forest.logClearance, "level 2 fits a log")
		t.expect(plantHeight(3) > Map.Forest.logClearance, "level 3 doesn't")
	end)

	t.test("rises: First over the tunnels, Second one jump more, Third blocks", function()
		local hills = Map.Hills
		local heights = hills.riseHeights
		t.expect(
			heights[1] >= hills.tunnelClearance + 2,
			"First Rise is a stud over the tunnel roof"
		)
		t.expect(heights[2] - heights[1] < Plants.jumpHeight, "Second Rise is one more jump")
		t.expect(heights[3] - heights[2] > Plants.jumpHeight, "Third Rise can't be jumped")
		t.expect(heights[3] - heights[2] > Plants.flyHeight - 12, "bats can't fly over it")
		-- The pillar right of centre has its own heights.
		local pillar = hills.pillar
		t.expectEqual(MapRules.riseHeight(Map, 3, pillar.x, pillar.z), pillar.heights[3])
		t.expectEqual(MapRules.riseHeight(Map, 1, 200, -300), heights[1])
		t.expectEqual(MapRules.hillsLayer(HillsShape, pillar.x, pillar.z), 3)
		t.expectEqual(MapRules.hillsHeight(Map, HillsShape, pillar.x, pillar.z), pillar.heights[3])
	end)

	t.test("rock over tunnels and the cave sits above the arch on terrain cells", function()
		local hills = Map.Hills
		t.expectEqual(hills.tunnelRockBottom % hills.terrainCell, 0)
		t.expectEqual(hills.caveRockBottom % hills.terrainCell, 0)
		t.expect(hills.tunnelRockBottom > hills.tunnelClearance, "rock above the tunnel arch")
		t.expect(hills.caveRockBottom > hills.caveClearance, "rock above the cave arch")
		t.expect(hills.caveRockTop > hills.caveRockBottom, "the cave is covered")
		t.expect(hills.riseHeights[1] >= hills.tunnelRockBottom, "First Rise covers a tunnel")
		-- Bottom left hill: no terrain cell reaches into its tunnel, and the
		-- tunnel walls reach the nearest terrain cell.
		local ridge = HillsShape.ridge
		local cellReach = hills.terrainCell / 2 * (math.abs(ridge.dx) + math.abs(ridge.dz))
		t.expect(hills.ridgeWallWidth >= 2 * cellReach, "tunnel walls meet the hill's rock")
		for j, row in MapRules.hillsGrid(Map, HillsShape) do
			for i, entry in row do
				local x, z = (i - 0.5) * hills.terrainCell, -(j - 0.5) * hills.terrainCell
				local _, along, across = MapRules.ridgeOffset(HillsShape, x, z)
				if entry[2] > 0 and math.abs(along) <= ridge.length / 2 then
					t.expect(
						math.abs(across) - cellReach >= hills.ridgeTunnelWidth / 2,
						"no rock in the bottom left hill's tunnel"
					)
				end
			end
		end
		local grid = MapRules.hillsGrid(Map, HillsShape)
		for j, row in grid do
			for i, entry in row do
				local x, z = (i - 0.5) * hills.terrainCell, -(j - 0.5) * hills.terrainCell
				if entry[1] > 0 then
					t.expect(
						MapRules.inTunnel(Map, HillsShape, x, z),
						"raised rock only over tunnels"
					)
				end
			end
		end
		-- A tunnel cell is a few studs from a wall; deep in the cave is far.
		t.expect(
			MapRules.distanceToCells(Map, grid, 150, -250, 12, MapRules.isWallCell, true) < 8,
			"tunnel walls are close"
		)
	end)

	t.test("hills areas: rises, tunnels, cave and the bottom left hill", function()
		t.expectEqual(
			MapRules.areaAt(Map, Map.Hills.pillar.x, Map.Hills.pillar.z, HillsShape),
			"ThirdRise"
		)
		t.expectEqual(MapRules.areaAt(Map, 230, -110, HillsShape), "Land") -- Second Rise
		t.expectEqual(MapRules.areaAt(Map, 200, -300, HillsShape), "Land") -- ground
		t.expectEqual(MapRules.areaAt(Map, 150, -250, HillsShape), "Tunnel")
		local cave = HillsShape.caveRooms[1]
		local cx, cz = 0, 0
		for _, corner in cave do
			cx += corner[1] / #cave
			cz += corner[2] / #cave
		end
		t.expect(MapRules.inCave(HillsShape, cx, cz), "cave middle is in the cave")
		t.expectEqual(MapRules.areaAt(Map, cx, cz, HillsShape), "Tunnel")
		local bottom, top = MapRules.hillsRock(Map, HillsShape, cx, cz)
		t.expectEqual(bottom, Map.Hills.caveRockBottom)
		t.expect(top >= Map.Hills.caveRockTop, "cave roof is covered")
		local ridge = HillsShape.ridge
		local rise = Map.Hills.riseHeights[1]
		t.expectEqual(MapRules.areaAt(Map, ridge.x, ridge.z, HillsShape), "Tunnel")
		t.expectEqual(MapRules.hillsHeight(Map, HillsShape, ridge.x, ridge.z), rise)
		-- Off the tunnel, the hill is First Rise rock.
		local patch = Map.Hills.firstHill.rockPatches[3]
		local px, pz = (patch[1][1] + patch[3][1]) / 2, (patch[1][2] + patch[3][2]) / 2
		t.expect(MapRules.onFirstHill(Map, HillsShape, px, pz), "patch is on the hill")
		local _, hillTop, hillLayer = MapRules.hillsRock(Map, HillsShape, px, pz)
		t.expectEqual(hillTop, rise)
		t.expectEqual(hillLayer, 1)
		t.expectEqual(MapRules.hillsHeight(Map, HillsShape, px, pz), rise)
		t.expect(
			not MapRules.onFirstHill(Map, HillsShape, ridge.x - 40, ridge.z + 40),
			"off the hill"
		)
		t.expectEqual(MapRules.areaAt(Map, 150, -250), "Land")
	end)

	t.test("ramps climb from the ground to the First Rise in pieces", function()
		local rise = Map.Hills.riseHeights[1]
		local sections = MapRules.rampSections(Map, HillsShape)
		local ramps, extends = table.clone(HillsShape.ramps), {}
		for _ in HillsShape.ramps do
			table.insert(extends, Map.Hills.rampExtend)
		end
		for _, ramp in Map.Hills.firstHill.ramps do
			table.insert(ramps, ramp)
			table.insert(extends, Map.Hills.firstHill.rampExtend)
		end
		t.expectEqual(#sections, #ramps * 3)
		for index, ramp in ramps do
			local hx = (ramp.high[1][1] + ramp.high[2][1]) / 2
			local hz = (ramp.high[1][2] + ramp.high[2][2]) / 2
			local lx = (ramp.low[1][1] + ramp.low[2][1]) / 2
			local lz = (ramp.low[1][2] + ramp.low[2][2]) / 2
			local length = math.sqrt((hx - lx) ^ 2 + (hz - lz) ^ 2)
			local ux, uz = (hx - lx) / length, (hz - lz) / length
			local total = length + extends[index]
			-- Height of this ramp's own pieces (ramps may meet at the foot).
			local function at(share)
				local x, z = hx - ux * total * (1 - share), hz - uz * total * (1 - share)
				local best = 0
				for _, section in sections do
					if section.ramp == index then
						local rx, rz = x - section.x, z - section.z
						local along = rx * section.ax + rz * section.az
						local across = -rx * section.az + rz * section.ax
						if
							math.abs(along) <= section.length / 2
							and math.abs(across) <= section.width / 2
						then
							local height = section.low
								+ (section.high - section.low) * (along / section.length + 0.5)
							best = math.max(best, height)
						end
					end
				end
				return best
			end
			t.expect(at(0.01) < 0.5, `ramp {index} starts at the ground`)
			t.expect(math.abs(at(0.99) - rise) < 0.6, `ramp {index} ends at the First Rise`)
			local last = -1
			for step = 1, 19 do
				local height = at(step / 20)
				t.expect(height >= last - 0.3, `ramp {index} keeps climbing`)
				last = height
			end
			-- Not too steep to walk up.
			for _, section in sections do
				local slope = math.deg(math.atan((section.high - section.low) / section.length))
				t.expect(slope < 30, "ramp slope under 30 degrees")
			end
			t.expectEqual(
				MapRules.hillsHeight(Map, HillsShape, hx + ux * 4, hz + uz * 4),
				rise,
				"the First Rise starts past the top"
			)
			t.expect(
				not MapRules.inField(Map, hx - ux * total, hz - uz * total),
				`ramp {index} stays out of the safe field`
			)
		end
	end)

	t.test("cliff sand wanders between its widths", function()
		local low, high = math.huge, -math.huge
		for x = 0, 350, 7 do
			for z = -350, 0, 7 do
				local width = MapRules.cliffSandWidth(Map, x, z)
				low, high = math.min(low, width), math.max(high, width)
			end
		end
		t.expect(low >= Map.Hills.cliffSandMinWidth, "not under the min")
		t.expect(high <= Map.Hills.cliffSandMaxWidth, "not over the max")
		t.expect(high - low > 4, "the width changes")
	end)

	t.test("a plant too big for the tunnels gets out at the nearest way out", function()
		local cave = HillsShape.caveRooms[1]
		local cx, cz = 0, 0
		for _, corner in cave do
			cx += corner[1] / #cave
			cz += corner[2] / #cave
		end
		local ridge = HillsShape.ridge
		for _, start in { { cx, cz }, { 150, -250 }, { ridge.x, ridge.z } } do
			local x, z = MapRules.tunnelExit(Map, HillsShape, start[1], start[2])
			t.expect(x ~= nil and z ~= nil, `a way out from {start[1]}, {start[2]}`)
			if x and z then
				t.expect(not MapRules.inTunnel(Map, HillsShape, x, z), "out of the tunnel")
				t.expectEqual(MapRules.hillsHeight(Map, HillsShape, x, z), 0)
			end
		end
		-- The bottom left hill's tunnel: out of one of its two ends.
		local x, z = MapRules.tunnelExit(Map, HillsShape, ridge.x, ridge.z)
		local _, along = MapRules.ridgeOffset(HillsShape, x :: number, z :: number)
		t.expect(math.abs(along) > ridge.length / 2, "out of an end, not through the wall")
		t.expectEqual(MapRules.tunnelExit(Map, HillsShape, 200, -300), nil)
	end)

	t.test("cave lanterns: two on each long wall, at the wall, facing in", function()
		local grid = MapRules.hillsGrid(Map, HillsShape)
		local spots = MapRules.caveLanternSpots(Map, HillsShape, grid)
		t.expectEqual(#spots, 2 * Map.Hills.caveLanternsPerWall)
		local cell = Map.Hills.terrainCell
		for _, spot in spots do
			local x, z, nx, nz = spot[1], spot[2], spot[3], spot[4]
			-- Its spot (just in from the wall) is under the cave's rock.
			local ix, iz = x + nx * 0.1, z + nz * 0.1
			local under = grid[math.floor(-iz / cell) + 1][math.floor(ix / cell) + 1]
			t.expect(under[1] > 0, "lantern is under the cave rock")
			t.expect(
				MapRules.distanceToCells(Map, grid, x, z, 4, MapRules.isWallCell, true) < 0.5,
				"lantern is at the wall"
			)
			-- A lantern's light hangs inside the cave, not in the rock.
			local hx, hz = x + nx * 2, z + nz * 2
			local entry = grid[math.floor(-hz / cell) + 1][math.floor(hx / cell) + 1]
			t.expect(not MapRules.isWallCell(entry), "lantern hangs in the open")
		end
		-- Two walls: the spots on each side face opposite ways.
		t.expect(spots[1][3] * spots[3][3] + spots[1][4] * spots[3][4] < 0, "opposite walls")
	end)

	t.test("land creatures may go on the First Rise, not in tunnels", function()
		t.expect(MapRules.creatureAllowed("Land", "FirstRise"), "land on First Rise")
		t.expect(not MapRules.creatureAllowed("Land", "Tunnel"), "land not in tunnels")
		t.expect(not MapRules.creatureAllowed("Land", "ThirdRise"), "nothing on the Third Rise")
		t.expect(not MapRules.creatureAllowed("FirstRise", "Land"), "chameleons stay up")
		t.expect(MapRules.creatureAllowed("Tunnel", "Land"), "bats wander out of the tunnels")
		t.expect(not MapRules.spawnAllowed("Tunnel", "Land"), "but spawn in them")
		t.expectEqual(MapRules.creatureArea(Map, "bat", true), "Tunnel")
		t.expectEqual(MapRules.creatureArea(Map, "snake", true), "FirstRise")
		t.expectEqual(MapRules.creatureArea(Map, "bat", false), "Land")
		local seed = 3
		local function random()
			seed = (seed * 16807 + 12345) % 2147483647
			return seed / 2147483647
		end
		for _, home in { "Tunnel", "FirstRise", "Land" } do
			for _ = 1, 20 do
				local x, z = MapRules.randomPointInArea(Map, "Hills", home, random, HillsShape)
				local area = MapRules.areaAt(Map, x, z, HillsShape)
				t.expect(MapRules.spawnAllowed(home, area), `{home} creature spawns in {area}`)
				t.expectEqual(MapRules.territoryAt(Map, x, z), "Hills")
			end
		end
	end)

	t.test("spawn mix: mostly native, some neighbours, a few from opposite", function()
		local neighbours, opposite = MapRules.relatives(Map, "Grassland")
		t.expectEqual(#neighbours, 2)
		t.expectEqual(opposite, "River")
		local mix = { native = 0.7, neighbour = 0.2, opposite = 0.1 }
		local function fixed(value)
			return function()
				return value
			end
		end
		t.expectEqual(MapRules.spawnSource(Map, "Grassland", mix, fixed(0.5)), "Grassland")
		local neighbour = MapRules.spawnSource(Map, "Grassland", mix, fixed(0.8))
		t.expect(neighbour == "Forest" or neighbour == "Hills", "neighbour")
		t.expectEqual(MapRules.spawnSource(Map, "Grassland", mix, fixed(0.95)), "River")
	end)
end
