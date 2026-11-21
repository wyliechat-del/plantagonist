--[[
	Things on the ground that a plant eats by touching: nuts, fruit and cow poo.
]]

local Pickups = {}

-- Seconds before an uneaten pickup disappears.
Pickups.nutLifetime = 30
Pickups.fruitLifetime = 45
Pickups.pooLifetime = 90

-- Seconds after landing before a pickup can be eaten, so a bitten plant
-- doesn't swallow its own nuts and fruit straight back.
Pickups.readyDelay = 1

-- Pickups land within this many studs of where they drop.
Pickups.scatterRadius = 6

-- Rings for eating a fruit (on top of the power up it carries).
Pickups.ringsPerFruit = 1

-- How close (in studs, on top of the plant's size) counts as touching.
Pickups.touchDistance = 3

-- Seconds between touch checks on the server.
Pickups.checkEverySeconds = 0.2

return table.freeze(Pickups)
