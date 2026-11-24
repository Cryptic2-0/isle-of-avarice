--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Relics = require(ReplicatedStorage.Shared.Catalog.Relics)
local World = require(ReplicatedStorage.Shared.Catalog.World)
local Scarcity = require(ReplicatedStorage.Shared.Rules.Scarcity)
local Sources = require(ReplicatedStorage.Shared.Rules.Sources)
local DataService = require(script.Parent.DataService)
local LedgerService = require(script.Parent.LedgerService)

local SourceService = {}

local coinSync: RemoteEvent

-- Copies of the Relic held on this server, claimed and spare alike.
function SourceService.held(relicId: string): number
	return Scarcity.countHeld(LedgerService.all(), relicId)
end

local function isSealed(relicId: string): boolean
	return Scarcity.isSealed(relicId, SourceService.held(relicId))
end

-- The one way a reward Relic (creature drop, trial, quest) reaches a Ledger. It goes to a
-- free slot under the same rules as a cache, and the player is told the result here:
-- GOT_CARD, REWARD_SEALED, REWARD_LOST (free slots full) or REWARD_LOCKED. Returns that
-- code; DATA_NOT_LOADED and UNKNOWN_CARD are returned without a message.
function SourceService.award(player: Player, relicId: string): string
	-- No yielding call between reading the Ledger and storing the new one.
	local newLedger, code = Sources.give(
		LedgerService.get(player),
		relicId,
		isSealed(relicId),
		LedgerService.isLocked(player)
	)
	local relic = Relics.byId[relicId]
	local args = { name = if relic ~= nil then relic.name else "" }
	if newLedger ~= nil then
		if not LedgerService.set(player, newLedger) then
			return "DATA_NOT_LOADED"
		end
		LedgerService.notify(player, "GOT_CARD", args)
		return "GOT_CARD"
	end
	local told = if code == "SEALED"
		then "REWARD_SEALED"
		elseif code == "FREE_FULL" then "REWARD_LOST"
		elseif code == "LEDGER_LOCKED" then "REWARD_LOCKED"
		else nil
	if told == nil then
		return code
	end
	LedgerService.notify(player, told, args)
	return told
end

-- Adds Coin (or takes it, with a negative delta) and tells the client. False, with nothing
-- changed, for a delta that is not a finite number, unloaded data, or a result below 0.
function SourceService.addCoin(player: Player, delta: number): boolean
	if not (delta > -math.huge and delta < math.huge) then
		return false
	end
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local coin = data.coin + delta
	if not (coin >= 0 and coin < math.huge) then
		return false
	end
	data.coin = coin
	if player.Parent == Players then
		coinSync:FireClient(player, coin)
	end
	return true
end

-- Sealed caches read "Sealed cache" with a dull pillar; open ones read "Cache" with a glowing one.
local function showSealed(part: BasePart, sealed: boolean)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if prompt ~= nil then
		prompt.ObjectText = if sealed then "Sealed cache" else "Cache"
	end
	local pillar = part:FindFirstChild("Pillar")
	if pillar ~= nil and pillar:IsA("BasePart") then
		pillar.Material = if sealed then Enum.Material.SmoothPlastic else Enum.Material.Neon
	end
end

local function setVisible(part: BasePart, visible: boolean)
	local transparency = if visible then 0 else 1
	part.Transparency = transparency
	part.CanCollide = visible
	local pillar = part:FindFirstChild("Pillar")
	if pillar ~= nil and pillar:IsA("BasePart") then
		pillar.Transparency = transparency
		pillar.CanCollide = visible
	end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if prompt ~= nil then
		prompt.Enabled = visible
	end
end

local function distanceToPlayer(player: Player, part: BasePart): number
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return math.huge
	end
	return (root.Position - part.Position).Magnitude
end

function SourceService.start()
	coinSync = LedgerService.makeRemote(Net.CoinSync)
	DataService.onLoaded(function(player, data)
		if player.Parent == Players then
			coinSync:FireClient(player, data.coin)
		end
	end)

	local state = Sources.new(World.caches)

	local cacheParts: { BasePart } = {}

	local function refreshSealed()
		for _, part in cacheParts do
			local cacheId = part:GetAttribute("CacheId")
			local cache = if type(cacheId) == "string" then World.cacheById[cacheId] else nil
			if cache ~= nil then
				showSealed(part, isSealed(cache.relicId))
			end
		end
	end

	local function connect(part: Instance)
		if not part:IsA("BasePart") then
			return
		end
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt == nil then
			return
		end
		table.insert(cacheParts, part)
		prompt.Triggered:Connect(function(player: Player)
			local cacheId = part:GetAttribute("CacheId")
			local cache = if type(cacheId) == "string" then World.cacheById[cacheId] else nil
			if cache == nil then
				return
			end

			-- No yielding call between tryCollect and storing the new state.
			local now = os.clock()
			local newState, newLedger, code, availableAt = Sources.tryCollect(
				state,
				LedgerService.get(player),
				cache,
				now,
				distanceToPlayer(player, part),
				isSealed(cache.relicId),
				LedgerService.isLocked(player)
			)
			if newLedger == nil or availableAt == nil then
				LedgerService.notify(player, code)
				return
			end
			if not LedgerService.set(player, newLedger) then
				-- The data went away; the cache stays as it was.
				LedgerService.notify(player, "DATA_NOT_LOADED")
				return
			end
			state = newState
			local relic = Relics.byId[cache.relicId]
			LedgerService.notify(player, code, { name = if relic ~= nil then relic.name else "" })

			setVisible(part, false)
			task.delay(availableAt - now, setVisible, part, true)
		end)
	end

	for _, instance in CollectionService:GetTagged("Cache") do
		connect(instance)
	end

	LedgerService.onChanged(refreshSealed)
	DataService.onLoaded(refreshSealed)
	Players.PlayerRemoving:Connect(function()
		-- One frame later, once the leaving player's data is gone (held players stay counted).
		task.defer(refreshSealed)
	end)
	refreshSealed()
end

return SourceService
