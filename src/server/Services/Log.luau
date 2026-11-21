--[[
	Event logging for playtests. Prints to the server Output and, when
	enabled, sends custom events to Roblox analytics.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logging = require(ReplicatedStorage.Shared.Config.Logging)

local Log = {}

local warned = false

-- `name` is a short event name such as "ReachedLevel4". `value` is a number
-- (seconds, a level). `details` is printed only.
function Log.event(player: Player?, name: string, value: number?, details: string?)
	if Logging.printEvents then
		local who = if player then player.Name else "server"
		print(`[Log] {name} {who} value={value or ""} {details or ""}`)
	end
	if Logging.sendAnalytics and player then
		local ok, err = pcall(function()
			AnalyticsService:LogCustomEvent(player, name, value or 1)
		end)
		if not ok and not warned then
			warned = true
			warn(`[Log] analytics unavailable: {err}`)
		end
	end
end

return Log
