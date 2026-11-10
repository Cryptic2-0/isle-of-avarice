--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ledger = require(ReplicatedStorage.Shared.Rules.Ledger)
local LedgerActions = require(ReplicatedStorage.Shared.Rules.LedgerActions)
local RateLimiter = require(ReplicatedStorage.Shared.Rules.RateLimiter)
local Net = require(ReplicatedStorage.Shared.Net)
local Relics = require(ReplicatedStorage.Shared.Catalog.Relics)
local Types = require(ReplicatedStorage.Shared.Types)
local DataService = require(script.Parent.DataService)

type Ledger = Types.Ledger

local BUCKET_CAPACITY = 10
local BUCKET_REFILL_PER_SECOND = 5

local LedgerService = {}

local ledgerSync: RemoteEvent
local ledgerAction: RemoteEvent
local ledgerRequest: RemoteEvent
local notifyRemote: RemoteEvent

local buckets: { [Player]: RateLimiter.Bucket } = {}
local completed: { [Player]: boolean } = {}

-- The player's Ledger, or nil until their data has loaded and after they left.
function LedgerService.get(player: Player): Ledger?
	local data = DataService.get(player)
	if data == nil then
		return nil
	end
	return data.ledger
end

-- Writes the Ledger to saved data and tells that player's client. Ignored if no data is loaded.
function LedgerService.set(player: Player, ledger: Ledger)
	local data = DataService.get(player)
	if data == nil then
		return
	end
	data.ledger = ledger
	ledgerSync:FireClient(player, ledger)
end

function LedgerService.notify(player: Player, code: string, args: { [string]: string }?)
	notifyRemote:FireClient(player, code, args)
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
	if not allowed(player) then
		return
	end
	local ledger = LedgerService.get(player)
	if ledger ~= nil then
		ledgerSync:FireClient(player, ledger)
	end
end

local function handleAction(player: Player, request: any)
	if not allowed(player) then
		LedgerService.notify(player, "SLOW_DOWN")
		return
	end

	-- No yielding call from here to set(): the Ledger read cannot go stale.
	local newLedger, code, cardId = LedgerActions.apply(LedgerService.get(player), request)
	if newLedger == nil then
		LedgerService.notify(player, code)
		return
	end
	LedgerService.set(player, newLedger)
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

	local function makeRemote(name: string): RemoteEvent
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	ledgerSync = makeRemote(Net.LedgerSync)
	ledgerAction = makeRemote(Net.LedgerAction)
	ledgerRequest = makeRemote(Net.LedgerRequest)
	notifyRemote = makeRemote(Net.Notify)

	ledgerAction.OnServerEvent:Connect(handleAction)
	ledgerRequest.OnServerEvent:Connect(handleRequest)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		completed[player] = nil
	end)

	DataService.onLoaded(function(player, data)
		-- A player may have left before this callback ran.
		if player.Parent == Players then
			ledgerSync:FireClient(player, data.ledger)
		end
	end)
end

return LedgerService
