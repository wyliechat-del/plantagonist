local HillsShape = require("../src/shared/Config/HillsShape")
local Map = require("../src/shared/Config/Map")
local Plants = require("../src/shared/Config/Plants")
local MapRules = require("../src/shared/Rules/Map")

local CHARACTER_HEIGHT = 5 -- a scale 1 Roblox character, roughly

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
		local height = CHARACTER_HEIGHT * Plants.scaleByLevel[bridge.passUnderMaxLevel]
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

	t.test("hiding grass hides levels 1 to 3 until they attack", function()
		local circle = Map.HidingGrass.circles[1]
		t.expect(MapRules.hiddenInGrass(Map, 3, circle.x, circle.z, 10, 0))
		t.expect(not MapRules.hiddenInGrass(Map, 4, circle.x, circle.z, 10, 0), "too big")
		t.expect(not MapRules.hiddenInGrass(Map, 1, circle.x, circle.z, 10, 12), "just attacked")
		t.expect(not MapRules.hiddenInGrass(Map, 1, 0, 0, 10, 0), "not in grass")
	end)

	t.test("rises: one jump each for the first two, the third blocks", function()
		local heights = Map.Hills.riseHeights
		t.expect(heights[1] < Plants.jumpHeight, "First Rise is one jump")
		t.expect(heights[2] - heights[1] < Plants.jumpHeight, "Second Rise is one more jump")
		t.expect(heights[3] - heights[2] > Plants.jumpHeight, "Third Rise can't be jumped")
		t.expect(heights[3] > Plants.flyHeight, "bats can't fly over the Third Rise")
	end)

	t.test("rock over tunnels and the cave leaves room and sits on terrain cells", function()
		local hills = Map.Hills
		local tunnelBottom = hills.tunnelClearance + hills.roofThickness
		local caveBottom = hills.caveClearance + hills.roofThickness
		t.expectEqual(tunnelBottom % 4, 0)
		t.expectEqual(caveBottom % 4, 0)
		t.expect(hills.tunnelRockTop > tunnelBottom, "rock above the tunnel roof")
		t.expect(hills.caveRockTop > caveBottom, "rock above the cave roof")
		t.expect(
			hills.ridgeHeight > hills.tunnelClearance + hills.roofThickness,
			"bottom left hill covers its tunnel"
		)
		t.expect(hills.ridgeFlatTop > hills.ridgeTunnelWidth, "flat top covers the tunnel")
		-- Every rock column over a tunnel starts at the roof.
		for x = 2, 350, 4 do
			for z = -350, -2, 4 do
				local bottom, top = MapRules.hillsRock(Map, HillsShape, x, z)
				if bottom > 0 then
					t.expect(
						MapRules.inTunnel(Map, HillsShape, x, z),
						"raised rock only over tunnels"
					)
					t.expect(top > bottom, "rock is above its floor")
				end
			end
		end
	end)

	t.test("hills areas: rises, tunnels, cave and the bottom left hill", function()
		t.expectEqual(MapRules.areaAt(Map, 260, -240, HillsShape), "ThirdRise")
		t.expectEqual(MapRules.areaAt(Map, 230, -110, HillsShape), "Land") -- Second Rise
		t.expectEqual(MapRules.areaAt(Map, 200, -300, HillsShape), "Land") -- ground
		t.expectEqual(MapRules.areaAt(Map, 150, -250, HillsShape), "Tunnel")
		-- The cave is in the big tunnel, under rock taller than the cave.
		local cave = HillsShape.caveRooms[1]
		local cx, cz = 0, 0
		for _, corner in cave do
			cx += corner[1] / #cave
			cz += corner[2] / #cave
		end
		t.expect(MapRules.inCave(HillsShape, cx, cz), "cave middle is in the cave")
		t.expectEqual(MapRules.areaAt(Map, cx, cz, HillsShape), "Tunnel")
		local bottom, top = MapRules.hillsRock(Map, HillsShape, cx, cz)
		t.expectEqual(bottom, Map.Hills.caveClearance + Map.Hills.roofThickness)
		t.expect(top >= Map.Hills.caveRockTop, "cave roof is covered")
		-- The bottom left hill: tunnel along the middle, flat top over it,
		-- ground level at its sides.
		local ridge = HillsShape.ridge
		t.expectEqual(MapRules.areaAt(Map, ridge.x, ridge.z, HillsShape), "Tunnel")
		t.expectEqual(
			MapRules.hillsHeight(Map, HillsShape, ridge.x, ridge.z),
			Map.Hills.ridgeHeight
		)
		t.expectEqual(MapRules.ridgeHeight(Map, HillsShape, ridge.width / 2), 0)
		-- Without the outlines, the Hills are plain land.
		t.expectEqual(MapRules.areaAt(Map, 150, -250), "Land")
	end)

	t.test("ramps rise from the ground to the First Rise", function()
		local rise = Map.Hills.riseHeights[1]
		for _, ramp in HillsShape.ramps do
			local function mid(edge)
				return (edge[1][1] + edge[2][1]) / 2, (edge[1][2] + edge[2][2]) / 2
			end
			local hx, hz = mid(ramp.high)
			local lx, lz = mid(ramp.low)
			local function at(share)
				return MapRules.hillsHeight(
					Map,
					HillsShape,
					lx + (hx - lx) * share,
					lz + (hz - lz) * share
				)
			end
			t.expect(at(0.02) < 0.5, "low end at the ground")
			t.expect(math.abs(at(0.98) - rise) < 0.5, "high end at the First Rise")
			t.expect(at(0.5) > at(0.25), "rises along the ramp")
			-- Just past the high edge is the First Rise.
			t.expectEqual(
				MapRules.hillsLayer(HillsShape, hx + (hx - lx) * 0.15, hz + (hz - lz) * 0.15),
				1
			)
		end
	end)

	t.test("land creatures may go on the First Rise, not in tunnels", function()
		t.expect(MapRules.creatureAllowed("Land", "FirstRise"), "land on First Rise")
		t.expect(not MapRules.creatureAllowed("Land", "Tunnel"), "land not in tunnels")
		t.expect(not MapRules.creatureAllowed("Land", "ThirdRise"), "nothing on the Third Rise")
		t.expect(not MapRules.creatureAllowed("FirstRise", "Land"), "chameleons stay up")
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
				t.expect(MapRules.creatureAllowed(home, area), `{home} creature in {area}`)
				t.expectEqual(MapRules.territoryAt(Map, x, z), "Hills")
			end
		end
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

	t.test("tunnels fit levels 1 to 3, logs fit levels 1 and 2", function()
		local function height(level)
			return CHARACTER_HEIGHT * Plants.scaleByLevel[level]
		end
		local hills = Map.Hills
		t.expect(height(3) < hills.tunnelClearance, "level 3 fits a tunnel")
		t.expect(height(4) > hills.tunnelClearance, "level 4 doesn't")
		t.expect(height(2) < Map.Forest.logClearance, "level 2 fits a log")
		t.expect(height(3) > Map.Forest.logClearance, "level 3 doesn't")
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
