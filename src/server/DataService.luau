--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crown = require(ReplicatedStorage.Shared.Rules.Crown)
local Ledger = require(ReplicatedStorage.Shared.Rules.Ledger)
local PathProgress = require(ReplicatedStorage.Shared.Rules.PathProgress)
local Rounds = require(ReplicatedStorage.Shared.Rules.Rounds)
local TrialRun = require(ReplicatedStorage.Shared.Rules.TrialRun)
local Types = require(ReplicatedStorage.Shared.Types)
local Vault = require(ReplicatedStorage.Shared.Rules.Vault)
local ProfileStore = require(script.Parent.Vendor.ProfileStore)

type PlayerData = Types.PlayerData

local DataService = {}

local TEMPLATE = {
	schemaVersion = 1,
	ledger = { claimed = {}, free = {} },
	coin = 0,
	vault = {},
	shieldEnded = false,
	paths = PathProgress.new(),
	trials = TrialRun.newRecord(),
	crown = Crown.newRecord(),
	rounds = Rounds.new(),
}

-- Longest a leaving player's profile stays open for holds.
local MAX_HOLD_SECONDS = 45
local HOLD_POLL_SECONDS = 0.25
-- Longest a rejoining player waits for their earlier, still held profile on this server to close.
-- A hold ends within MAX_HOLD_SECONDS; this only stops a stuck wait.
local REJOIN_WAIT_SECONDS = 180
local LOAD_FAILED = "Your data could not be loaded. Please rejoin."

local store = ProfileStore.New("PlayerData_v1", TEMPLATE)

-- Active profiles by player. An entry exists only between a finished load and its release.
local profiles: { [Player]: any } = {}
-- Players whose load is in flight, so a player is never loaded twice.
local loading: { [Player]: boolean } = {}
-- Players whose session is being ended because they are leaving, so they are not kicked.
local leaving: { [Player]: boolean } = {}
-- Number of open holds per player; a held profile stays open after the player has left.
local holds: { [Player]: number } = {}
local beforeReleaseCallbacks: { (player: Player) -> () } = {}
local loadedCallbacks: { (player: Player, data: PlayerData) -> () } = {}

local function fireLoaded(player: Player, data: PlayerData)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

-- True while this server still has the same user's profile open under an earlier Player object:
-- they left and rejoined here while a hold (a combat-log claim) keeps their old profile open.
local function openUnderEarlierPlayer(player: Player): boolean
	for other, profile in profiles do
		if other ~= player and other.UserId == player.UserId and profile:IsActive() then
			return true
		end
	end
	return false
end

local function loadProfile(player: Player)
	if profiles[player] ~= nil or loading[player] then
		return
	end
	loading[player] = true

	-- ProfileStore refuses a second session for a key this server already has open, so wait
	-- for the hold to end; the release save then lands before this load reads.
	local waitUntil = os.clock() + REJOIN_WAIT_SECONDS
	while openUnderEarlierPlayer(player) do
		if player.Parent ~= Players then
			loading[player] = nil
			return
		end
		if os.clock() >= waitUntil then
			loading[player] = nil
			player:Kick(LOAD_FAILED)
			return
		end
		task.wait(HOLD_POLL_SECONDS)
	end

	local ok, result = pcall(function()
		return store:StartSessionAsync(tostring(player.UserId), {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})
	end)
	loading[player] = nil
	if not ok then
		warn(`[IsleOfAvarice] loading data for {player.UserId} failed: {result}`)
	end
	local profile = if ok then result else nil

	if profile == nil then
		-- Cancelled because the player left (Kick is then a harmless no-op) or the load failed.
		if player.Parent == Players then
			player:Kick(LOAD_FAILED)
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
	profile.Data.vault = Vault.sanitize(profile.Data.vault, profile.Data.ledger)
	profile.Data.paths = PathProgress.sanitize(profile.Data.paths)
	profile.Data.trials = TrialRun.sanitize(profile.Data.trials, os.time())
	profile.Data.crown = Crown.sanitize(profile.Data.crown)
	profile.Data.rounds = Rounds.sanitize(profile.Data.rounds)
	if type(profile.Data.shieldEnded) ~= "boolean" then
		profile.Data.shieldEnded = false
	end
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

-- Runs when a player is leaving, before the profile is released. Holds are taken here.
function DataService.beforeRelease(callback: (player: Player) -> ())
	table.insert(beforeReleaseCallbacks, callback)
end

-- Keeps the player's profile open (for up to MAX_HOLD_SECONDS after they leave).
-- Returns a function that lets go; it works once only.
function DataService.hold(player: Player): () -> ()
	holds[player] = (holds[player] or 0) + 1
	local released = false
	return function()
		if released then
			return
		end
		released = true
		local count = holds[player]
		if count ~= nil then
			holds[player] = if count > 1 then count - 1 else nil
		end
	end
end

local function handleRemoving(player: Player)
	for _, callback in beforeReleaseCallbacks do
		local ok, err = pcall(callback, player)
		if not ok then
			warn(`[IsleOfAvarice] beforeRelease callback failed: {err}`)
		end
	end
	local deadline = os.clock() + MAX_HOLD_SECONDS
	while holds[player] ~= nil and os.clock() < deadline do
		task.wait(HOLD_POLL_SECONDS)
	end
	holds[player] = nil
	releaseProfile(player)
end

-- Returns the player's saved data, or nil until it has loaded and after it was released.
function DataService.get(player: Player): PlayerData?
	local profile = profiles[player]
	if profile ~= nil and profile:IsActive() then
		return profile.Data
	end
	return nil
end

-- The saved data of every player whose profile is open, including held players who have left.
function DataService.all(): { PlayerData }
	local result: { PlayerData } = {}
	for _, profile in profiles do
		if profile:IsActive() then
			table.insert(result, profile.Data)
		end
	end
	return result
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
	Players.PlayerRemoving:Connect(handleRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
end

return DataService
