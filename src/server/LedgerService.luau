--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ledger = require(ReplicatedStorage.Shared.Rules.Ledger)
local LedgerActions = require(ReplicatedStorage.Shared.Rules.LedgerActions)
local RateLimiter = require(ReplicatedStorage.Shared.Rules.RateLimiter)
local Net = require(ReplicatedStorage.Shared.Net)
local Relics = require(ReplicatedStorage.Shared.Catalog.Relics)
local Types = require(ReplicatedStorage.Shared.Types)
local Vault = require(ReplicatedStorage.Shared.Rules.Vault)
local DataService = require(script.Parent.DataService)

type Ledger = Types.Ledger
type Vault = Types.Vault

local BUCKET_CAPACITY = 10
local BUCKET_REFILL_PER_SECOND = 5
local SLOW_DOWN_INTERVAL = 1

local LedgerService = {}

local ledgerSync: RemoteEvent
local ledgerAction: RemoteEvent
local ledgerRequest: RemoteEvent
local notifyRemote: RemoteEvent

local buckets: { [Player]: RateLimiter.Bucket } = {}
local completed: { [Player]: boolean } = {}
local lastSlowDown: { [Player]: number } = {}
local locked: { [Player]: boolean } = {}
local changedCallbacks: { (player: Player, ledger: Ledger) -> () } = {}
local remotesFolder: Folder?

-- The player's Ledger, or nil until their data has loaded and after they left.
function LedgerService.get(player: Player): Ledger?
	local data = DataService.get(player)
	if data == nil then
		return nil
	end
	return data.ledger
end

-- The player's Vault, or nil until their data has loaded and after they left.
function LedgerService.getVault(player: Player): Vault?
	local data = DataService.get(player)
	if data == nil then
		return nil
	end
	return data.vault
end

-- Ledgers of every player whose data is loaded (including held players who have left).
function LedgerService.all(): { Ledger }
	local result: { Ledger } = {}
	for _, data in DataService.all() do
		table.insert(result, data.ledger)
	end
	return result
end

-- A locked player's Ledger and Vault may not be changed by that player.
function LedgerService.lock(player: Player)
	locked[player] = true
end

function LedgerService.unlock(player: Player)
	locked[player] = nil
end

function LedgerService.isLocked(player: Player): boolean
	return locked[player] == true
end

function LedgerService.onChanged(callback: (player: Player, ledger: Ledger) -> ())
	table.insert(changedCallbacks, callback)
end

-- Creates a RemoteEvent in the Remotes folder. Works for services started after LedgerService.start().
function LedgerService.makeRemote(name: string): RemoteEvent
	local folder = remotesFolder
	assert(folder ~= nil, "LedgerService.start must run before makeRemote")
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

-- Writes the Ledger to saved data, prunes the Vault to match, and tells that player's client.
-- Returns false, changing nothing, if no data is loaded.
function LedgerService.set(player: Player, ledger: Ledger): boolean
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	data.ledger = ledger
	data.vault = Vault.prune(data.vault, ledger)
	if player.Parent == Players then
		ledgerSync:FireClient(player, ledger, data.vault)
	end
	for _, callback in changedCallbacks do
		task.spawn(callback, player, ledger)
	end
	return true
end

-- Writes the Vault to saved data and tells that player's client.
-- Returns false, changing nothing, if no data is loaded.
function LedgerService.setVault(player: Player, vault: Vault): boolean
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	data.vault = vault
	if player.Parent == Players then
		ledgerSync:FireClient(player, data.ledger, vault)
	end
	return true
end

function LedgerService.notify(player: Player, code: string, args: { [string]: string }?)
	notifyRemote:FireClient(player, code, args)
end

function LedgerService.notifyAll(code: string, args: { [string]: string }?)
	notifyRemote:FireAllClients(code, args)
end

-- True if the player has a token left in their rate-limit bucket (takes one).
local function allowed(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if bucket == nil then
		bucket = RateLimiter.new(BUCKET_CAPACITY, now)
		buckets[player] = bucket
	end
	return RateLimiter.allow(bucket, now, BUCKET_CAPACITY, BUCKET_REFILL_PER_SECOND)
end

local function handleRequest(player: Player)
	if player.Parent ~= Players then
		return
	end
	if not allowed(player) then
		return
	end
	local ledger = LedgerService.get(player)
	if ledger ~= nil then
		ledgerSync:FireClient(player, ledger, LedgerService.getVault(player) or {})
	end
end

local function handleAction(player: Player, request: any)
	if player.Parent ~= Players then
		return
	end
	if not allowed(player) then
		local now = os.clock()
		local last = lastSlowDown[player]
		if last == nil or now - last >= SLOW_DOWN_INTERVAL then
			lastSlowDown[player] = now
			LedgerService.notify(player, "SLOW_DOWN")
		end
		return
	end

	if LedgerService.isLocked(player) then
		LedgerService.notify(player, "LEDGER_LOCKED")
		return
	end

	-- No yielding call from here to set(): the Ledger read cannot go stale.
	local newLedger, code, cardId = LedgerActions.apply(LedgerService.get(player), request)
	if newLedger == nil then
		LedgerService.notify(player, code)
		return
	end
	if not LedgerService.set(player, newLedger) then
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return
	end
	local relic = if cardId ~= nil then Relics.byId[cardId] else nil
	LedgerService.notify(player, code, { name = if relic ~= nil then relic.name else "" })

	if code == "CLAIMED" and Ledger.isComplete(newLedger) and not completed[player] then
		completed[player] = true
		notifyRemote:FireAllClients("LEDGER_COMPLETE", { player = player.DisplayName })
	end
end

function LedgerService.start()
	local folder = Instance.new("Folder")
	folder.Name = Net.FOLDER
	folder.Parent = ReplicatedStorage

	remotesFolder = folder
	ledgerSync = LedgerService.makeRemote(Net.LedgerSync)
	ledgerAction = LedgerService.makeRemote(Net.LedgerAction)
	ledgerRequest = LedgerService.makeRemote(Net.LedgerRequest)
	notifyRemote = LedgerService.makeRemote(Net.Notify)

	ledgerAction.OnServerEvent:Connect(handleAction)
	ledgerRequest.OnServerEvent:Connect(handleRequest)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		completed[player] = nil
		lastSlowDown[player] = nil
		-- A held player's profile is still open; whoever holds it unlocks them.
		-- Deferred so the holds taken by other PlayerRemoving handlers exist by now.
		task.defer(function()
			if DataService.get(player) == nil then
				locked[player] = nil
			end
		end)
	end)

	DataService.onLoaded(function(player, data)
		-- A player may have left before this callback ran.
		if player.Parent == Players then
			ledgerSync:FireClient(player, data.ledger, data.vault)
		end
	end)
end

return LedgerService
