--[[
	Saved data per player: the codex (creatures eaten) and award progress.

	If DataStores aren't available (for example Studio without API access),
	progress still works for the session but isn't saved, and a warning is
	printed once.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Awards = require(ReplicatedStorage.Shared.Config.Awards)
local DataConfig = require(ReplicatedStorage.Shared.Config.Data)
local PowerUps = require(ReplicatedStorage.Shared.Config.PowerUps)
local AwardRules = require(ReplicatedStorage.Shared.Rules.Awards)

local Effects = require(script.Parent.Effects)
local Log = require(script.Parent.Log)

local Data = {}

type Entry = { progress: AwardRules.Progress, loaded: boolean, dirty: boolean }

local entries: { [Player]: Entry } = {}
local store: DataStore? = nil
local storeWarned = false

local function warnStore(err: any)
	if not storeWarned then
		storeWarned = true
		warn(`[Data] saving is off for this session: {err}`)
	end
end

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

local function withRetries(fn: () -> any): (boolean, any)
	local ok, result = false, nil
	for attempt = 1, DataConfig.retries do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < DataConfig.retries then
			task.wait(DataConfig.retryWaitSeconds)
		end
	end
	return false, result
end

local function load(player: Player)
	local entry: Entry = { progress = AwardRules.newProgress(), loaded = false, dirty = false }
	entries[player] = entry
	if store == nil then
		return
	end
	local activeStore = store
	local ok, result = withRetries(function()
		return activeStore:GetAsync(keyFor(player))
	end)
	if ok then
		entry.progress = AwardRules.repair(result)
		entry.loaded = true
	else
		-- Don't save over data we couldn't read.
		warnStore(result)
	end
end

local function save(player: Player)
	local entry = entries[player]
	if store == nil or entry == nil or not entry.loaded or not entry.dirty then
		return
	end
	local activeStore = store
	local ok, err = withRetries(function()
		activeStore:SetAsync(keyFor(player), entry.progress)
	end)
	if ok then
		entry.dirty = false
	else
		warnStore(err)
	end
end

-- Changes a player's progress with `change(progress)`, then announces any
-- awards that are now earned.
function Data.record(player: Player?, change: (AwardRules.Progress) -> ())
	if player == nil then
		return
	end
	local entry = entries[player]
	if entry == nil then
		return
	end
	change(entry.progress)
	entry.dirty = true
	for _, award in AwardRules.collectNew(Awards, PowerUps, entry.progress) do
		local reward = if award.cosmetic then ` You unlocked: {award.cosmetic}.` else ""
		Effects.notify(player, `Award: {award.name}!{reward}`, "award")
		Effects.send(player, "sound", { name = "levelUp" })
		Log.event(player, `Award_{award.id}`)
	end
end

function Data.count(player: Player?, stat: string, amount: number?)
	Data.record(player, function(progress)
		AwardRules.addCount(progress, stat, amount)
	end)
end

function Data.progressFor(player: Player): AwardRules.Progress?
	local entry = entries[player]
	return entry and entry.progress
end

function Data.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DataConfig.storeName)
	end)
	if ok then
		store = result
	else
		warnStore(result)
	end

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		entries[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(save, player)
		end
		task.wait(3)
	end)
	task.spawn(function()
		while true do
			task.wait(DataConfig.autosaveSeconds)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)
end

return Data
