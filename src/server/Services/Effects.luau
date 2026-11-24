--[[
	Messages and effects sent to clients through the Notify and Effect remotes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Effects = {}

function Effects.notify(player: Player?, text: string, kind: string?)
	if player then
		Remotes.event("Notify"):FireClient(player, text, kind)
	end
end

function Effects.notifyAll(text: string, kind: string?)
	Remotes.event("Notify"):FireAllClients(text, kind)
end

-- Sends an effect to one player.
function Effects.send(player: Player?, kind: string, data: { [string]: any }?)
	if player then
		Remotes.event("Effect"):FireClient(player, kind, data)
	end
end

-- Sends an effect to everyone.
function Effects.sendAll(kind: string, data: { [string]: any }?)
	Remotes.event("Effect"):FireAllClients(kind, data)
end

-- Plays a named sound (see Config/Sounds) at a position for everyone nearby.
function Effects.sound(name: string, position: Vector3?)
	Effects.sendAll("sound", { name = name, position = position })
end

-- Sends to every player except one.
function Effects.sendOthers(except: Player?, kind: string, data: { [string]: any }?)
	for _, player in Players:GetPlayers() do
		if player ~= except then
			Effects.send(player, kind, data)
		end
	end
end

return Effects
