--[[
	How plants look and behave in the world (placeholder art). Each level has a
	scale for the character; a scale of 1 is a standard Roblox character,
	about 5 studs tall.
]]

local Plants = {}

-- Character scale per level (index = level). Level 3 must fit caves
-- (`Config/Map.luau` Caves.clearance) and level 2 must fit hollow logs.
Plants.scaleByLevel = table.freeze({ 0.6, 0.8, 1.1, 1.6, 2.1, 2.6 })

-- Placeholder colours, { red, green, blue } from 0 to 255.
Plants.potColour = table.freeze({ 190, 100, 60 })
Plants.stemColour = table.freeze({ 70, 150, 60 })
Plants.headColour = table.freeze({ 90, 190, 70 })
Plants.mouthColour = table.freeze({ 200, 60, 80 })

-- Tossing: when a bigger plant bites a smaller one, the victim is thrown
-- away from the biter at this speed (studs per second), and up a little.
Plants.tossSpeed = 40
Plants.tossUpSpeed = 25

-- Jump height in studs (Roblox default 7.2). Strangled plants can't jump.
Plants.jumpHeight = 7.2

-- Blowfish ball: bounce speed away from danger.
Plants.ballBounceSpeed = 60

-- Bat flight: lift speed when taking off, in studs per second.
Plants.flyLiftSpeed = 20

-- A plant's body radius in studs at scale 1 (multiplied by the level's scale).
Plants.radiusAtScale1 = 1.5

-- Hit checks: extra studs allowed on top of reach for network lag.
Plants.hitTolerance = 4

-- Seconds a plant has to wait after spawning before it can bite.
Plants.spawnBiteDelay = 1

return table.freeze(Plants)
