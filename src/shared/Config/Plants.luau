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
-- Plants move this much faster while in the air (a jump is a burst of
-- speed), and must wait `jumpRefreshSeconds` after landing to jump again.
Plants.airSpeedMultiplier = 1.2
Plants.jumpRefreshSeconds = 1

-- Blowfish ball: bounce speed away from danger.
Plants.ballBounceSpeed = 60

-- Bat flight: rise at `flyLiftSpeed` to `flyHeight` studs above the ground
-- (above a level 6 plant), fly at `flySpeedMultiplier` times level 1 speed for
-- the bat's flight time, then glide down at `flyGlideSpeed`, for at most
-- `flyGlideMaxSeconds`.
Plants.flyLiftSpeed = 20
Plants.flyHeight = 18
Plants.flySpeedMultiplier = 1.5
Plants.flyGlideSpeed = 8
Plants.flyGlideMaxSeconds = 4
-- How hard the plant climbs back toward `flyHeight` (studs per second per
-- stud short), and how close to the ground a glide counts as landed.
Plants.flyHeightGain = 3
Plants.flyLandingStuds = 0.5
-- While flying, a ranged shot homes in on the plant nearest the click, within
-- `guideRadius` studs of it, flying `guideSpeedMultiplier` times faster and
-- reaching `guideRangeMultiplier` times further. Clicks count as on a plant
-- within `flyClickSlackStuds` of it.
Plants.guideRadius = 15
Plants.guideSpeedMultiplier = 2
Plants.guideRangeMultiplier = 1.5
Plants.flyClickSlackStuds = 8

-- A plant's body radius in studs at scale 1 (multiplied by the level's scale).
Plants.radiusAtScale1 = 1.5

-- Hit checks: extra studs allowed on top of reach for network lag.
Plants.hitTolerance = 4

-- Seconds a plant has to wait after spawning before it can bite.
Plants.spawnBiteDelay = 1

return table.freeze(Plants)
