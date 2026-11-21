--[[
	Saved player data (codex and award progress).
]]

local Data = {}

-- DataStore name. Change the version to start everyone fresh.
Data.storeName = "PlantagonistPlayers_v1"

-- Save every player this often, and when they leave or the server closes.
Data.autosaveSeconds = 120

-- Tries per load or save, and seconds between tries.
Data.retries = 3
Data.retryWaitSeconds = 2

return table.freeze(Data)
