--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ledger = require(ReplicatedStorage.Shared.Rules.Ledger)
local Types = require(ReplicatedStorage.Shared.Types)
local ProfileStore = require(script.Parent.Vendor.ProfileStore)

type PlayerData = Types.PlayerData

local DataService = {}

local TEMPLATE = {
	schemaVersion = 1,
	ledger = { claimed = {}, free = {} },
	coin = 0,
}

local store = ProfileStore.New("PlayerData_v1", TEMPLATE)

-- Active profiles by player. An entry exists only between a finished load and its release.
local profiles: { [Player]: any } = {}
-- Players whose load is in flight, so a player is never loaded twice.
local loading: { [Player]: boolean } = {}
-- Players whose session is being ended because they are leaving, so they are not kicked.
local leaving: { [Player]: boolean } = {}
local loadedCallbacks: { (player: Player, data: PlayerData) -> () } = {}

local function fireLoaded(player: Player, data: PlayerData)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function loadProfile(player: Player)
	if profiles[player] ~= nil or loading[player] then
		return
	end
	loading[player] = true

	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	loading[player] = nil

	if profile == nil then
		-- Cancelled because the player left (Kick is then a harmless no-op) or the load failed.
		if player.Parent == Players then
			player:Kick("Your data could not be loaded. Please rejoin.")
		end
		return
	end

	if player.Parent ~= Players then
		-- The player left while the profile was loading: release it and store nothing.
		profile:EndSession()
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.Data.ledger = Ledger.sanitize(profile.Data.ledger)
	local coin = profile.Data.coin
	if type(coin) ~= "number" or coin ~= coin or coin == math.huge or coin < 0 then
		profile.Data.coin = 0
	end

	profile.OnSessionEnd:Connect(function()
		if profiles[player] == profile then
			profiles[player] = nil
		end
		local isLeaving = leaving[player]
		leaving[player] = nil
		if player.Parent == Players and not isLeaving then
			player:Kick("Your data was loaded elsewhere. Please rejoin.")
		end
	end)

	profiles[player] = profile
	fireLoaded(player, profile.Data)
end

local function releaseProfile(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile ~= nil then
		leaving[player] = true
		profile:EndSession()
	end
end

-- Returns the player's saved data, or nil until it has loaded and after it was released.
function DataService.get(player: Player): PlayerData?
	local profile = profiles[player]
	if profile ~= nil and profile:IsActive() then
		return profile.Data
	end
	return nil
end

-- Registers a callback that runs (in its own thread) once a player's data is loaded and sanitised.
-- Players whose data is already loaded are reported immediately.
function DataService.onLoaded(callback: (player: Player, data: PlayerData) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		if profile:IsActive() then
			task.spawn(callback, player, profile.Data)
		end
	end
end

function DataService.start()
	Players.PlayerAdded:Connect(function(player)
		loadProfile(player)
	end)
	Players.PlayerRemoving:Connect(releaseProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
end

return DataService
