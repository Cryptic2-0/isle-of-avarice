--!strict
-- The Edict Hall clerk: packs, Copper Relics and selling spare cards. Shop holds every rule;
-- this service checks who is asking and how close they stand, then writes the Ledger and
-- Coin in one step. A sale or a purchase fully happens or does not happen at all.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Rules.RateLimiter)
local Shop = require(ReplicatedStorage.Shared.Rules.Shop)
local ShopCatalog = require(ReplicatedStorage.Shared.Catalog.Shop)
local World = require(ReplicatedStorage.Shared.Catalog.World)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)
local LedgerService = require(script.Parent.LedgerService)
local SourceService = require(script.Parent.SourceService)

local BUCKET_CAPACITY = 10
local BUCKET_REFILL_PER_SECOND = 5
local CLERK_TAG = "ShopClerk"
local ROOT_LIFT = 3 -- a standing character's root above the ground

local ShopService = {}

local buckets: { [Player]: RateLimiter.Bucket } = {}
local openRemote: RemoteEvent
local rng: () -> number = math.random

local function allowed(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if bucket == nil then
		bucket = RateLimiter.new(BUCKET_CAPACITY, now)
		buckets[player] = bucket
	end
	return RateLimiter.allow(bucket, now, BUCKET_CAPACITY, BUCKET_REFILL_PER_SECOND)
end

-- Play-test seam: the pack rolls (default math.random).
function ShopService.setRng(roll: () -> number)
	rng = roll
end

local function showShop(player: Player)
	local data = DataService.get(player)
	if data == nil then
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return
	end
	openRemote:FireClient(player, Shop.view(data.ledger, data.coin))
end

-- The client sends a purchase or a sale; everything else is checked here, in order: present
-- and not too fast, data loaded, Ledger not locked, standing at the clerk, then the rules.
local function handleAction(player: Player, raw: any)
	if player.Parent ~= Players or not allowed(player) then
		return
	end
	local data = DataService.get(player)
	if data == nil then
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return
	end
	if LedgerService.isLocked(player) then
		LedgerService.notify(player, "LEDGER_LOCKED")
		return
	end
	local _, root = Fighters.body(player.UserId)
	local clerk = World.clerk
	if root == nil then
		LedgerService.notify(player, "TOO_FAR")
		return
	end
	local distance = (root.Position - Vector3.new(clerk.x, clerk.y + ROOT_LIFT, clerk.z)).Magnitude
	-- Written positively so a NaN distance is refused.
	if not (distance <= ShopCatalog.REACH) then
		LedgerService.notify(player, "TOO_FAR")
		return
	end

	-- No yielding call from here to the writes: the Ledger and Coin read cannot go stale.
	local coinBefore = data.coin
	local newLedger, newCoin, code, args = Shop.apply(data.ledger, coinBefore, raw, rng)
	if newLedger == nil then
		LedgerService.notify(player, code, args)
		return
	end
	if not LedgerService.set(player, newLedger) then
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return
	end
	SourceService.addCoin(player, newCoin - coinBefore)
	LedgerService.notify(player, code, args)
	showShop(player)
end

local function connectClerk(instance: Instance)
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if prompt == nil then
		return
	end
	prompt.Triggered:Connect(function(player: Player)
		showShop(player)
	end)
end

function ShopService.start()
	openRemote = LedgerService.makeRemote(Net.ShopOpen)
	LedgerService.makeRemote(Net.ShopAction).OnServerEvent:Connect(handleAction)

	for _, instance in CollectionService:GetTagged(CLERK_TAG) do
		connectClerk(instance)
	end
	CollectionService:GetInstanceAddedSignal(CLERK_TAG):Connect(connectClerk)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return ShopService
