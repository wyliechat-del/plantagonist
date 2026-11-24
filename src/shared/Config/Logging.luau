--[[
	Event logging for playtests: time to each level, cause of every level drop
	and when players leave.
]]

local Logging = {}

-- Print each event to the server output (shows in Studio's Output window).
Logging.printEvents = true

-- Also send events to Roblox analytics (Creator Hub > Analytics).
Logging.sendAnalytics = true

return table.freeze(Logging)
