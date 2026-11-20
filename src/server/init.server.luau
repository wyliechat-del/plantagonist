-- Server entry point. Keep this thin: start systems, don't hold game logic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

Remotes.setup()

print("[Plantagonist] server started")
