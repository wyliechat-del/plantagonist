-- Server entry point. Keep this thin: start systems, don't hold game logic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

Remotes.setup()

local Services = script:WaitForChild("Services")

-- Start order matters: the map first, then plants, then things that use them.
local order = {
	"Data",
	"MapBuilder",
	"Plants",
	"Pickups",
	"Creatures",
	"Combat",
	"Zones",
	"Rain",
	"Rooting",
	"Npcs",
}

for _, name in order do
	local service = require(Services:WaitForChild(name)) :: any
	local ok, err = pcall(service.start)
	if not ok then
		warn(`[Plantagonist] {name} failed to start: {err}`)
	end
end

print("[Plantagonist] server started")
