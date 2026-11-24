--[[
	Remotes: the one place that lists every message between client and server.
	Add a name to `Events` or `Functions` here; nothing else in the game may
	create a RemoteEvent or RemoteFunction.

	The server calls `Remotes.setup()` once at start-up. Both sides then use
	`Remotes.event(name)` or `Remotes.func(name)`, which fail loudly on a typo.
]]

local Remotes = {}

-- RemoteEvents (fire and forget).
Remotes.Events = table.freeze({
	"Bite", -- client to server: (target: Instance?, point: Vector3?) bite, or miss at point
	"UseSlot", -- client to server: (index: number, target: Model?, point: Vector3?) use an attack slot
	"Root", -- client to server: () take root as a Deciduodocus
	"Respawn", -- client to server: () stop watching your new tree and start again
	"Notify", -- server to client: (text: string, kind: string?) pop-up message
	"Effect", -- server to client: (kind: string, data: table?) sounds, flashes, pushes
} :: { string })

-- RemoteFunctions (request and reply). Use sparingly.
Remotes.Functions = table.freeze({} :: { string })

local FOLDER_NAME = "Remotes"

local function getFolder(): Instance
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function assertListed(list: { string }, name: string)
	if not table.find(list, name) then
		error(`Remote "{name}" is not listed in Remotes.luau`, 3)
	end
end

-- Server only: create the folder and every listed remote.
function Remotes.setup()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in Remotes.Events do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in Remotes.Functions do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

function Remotes.event(name: string): RemoteEvent
	assertListed(Remotes.Events, name)
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	assertListed(Remotes.Functions, name)
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes
