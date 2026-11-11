--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protection = require(ReplicatedStorage.Shared.Rules.Protection)
local RateLimiter = require(ReplicatedStorage.Shared.Rules.RateLimiter)
local Vault = require(ReplicatedStorage.Shared.Rules.Vault)
local Net = require(ReplicatedStorage.Shared.Net)
local Relics = require(ReplicatedStorage.Shared.Catalog.Relics)
local LedgerService = require(script.Parent.LedgerService)

local BUCKET_CAPACITY = 10
local BUCKET_REFILL_PER_SECOND = 5

local VaultService = {}

local buckets: { [Player]: RateLimiter.Bucket } = {}

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

-- The server reads the position itself. No character counts as outside the safe zone.
local function playerInSafeZone(player: Player): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local p = root.Position
	return Protection.inSafeZone({ x = p.X, y = p.Y, z = p.Z })
end

local function handleAction(player: Player, request: any)
	if player.Parent ~= Players then
		return
	end
	if not allowed(player) then
		return
	end

	-- No yielding call from here to setVault(): the reads cannot go stale.
	local newVault, code, cardId = Vault.apply(
		LedgerService.getVault(player),
		LedgerService.get(player),
		request,
		playerInSafeZone(player),
		LedgerService.isLocked(player)
	)
	if newVault == nil then
		LedgerService.notify(player, code)
		return
	end
	if not LedgerService.setVault(player, newVault) then
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return
	end
	local relic = if cardId ~= nil then Relics.byId[cardId] else nil
	LedgerService.notify(player, code, { name = if relic ~= nil then relic.name else "" })
end

function VaultService.start()
	local vaultAction = LedgerService.makeRemote(Net.VaultAction)
	vaultAction.OnServerEvent:Connect(handleAction)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return VaultService
