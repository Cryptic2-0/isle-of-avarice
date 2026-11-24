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
local Fighters = require(script.Parent.Fighters)
local LedgerService = require(script.Parent.LedgerService)

local SourceService = {}

local coinSync: RemoteEvent
local coinCallbacks: { (player: Player, coin: number) -> () } = {}

-- Runs after every successful addCoin, in its own thread so it can never delay or break the write.
function SourceService.onCoinChanged(callback: (player: Player, coin: number) -> ())
	table.insert(coinCallbacks, callback)
end

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
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	-- No yield from this check to the write.
	local coin = Sources.coinAfter(data.coin, delta)
	if coin == nil then
		return false
	end
	data.coin = coin
	if player.Parent == Players then
		coinSync:FireClient(player, coin)
	end
	for _, callback in coinCallbacks do
		task.spawn(callback, player, coin)
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

type Hold = { began: number, ended: number? }

local state: Sources.SourceState = Sources.new(World.caches)
local cacheParts: { BasePart } = {}
-- part -> player -> when they started holding the prompt and when they let go. Cleared on every
-- trigger, when the player leaves, dies, respawns or goes out of reach, and for the whole part
-- when it opens.
local holds: { [BasePart]: { [Player]: Hold } } = {}

local function refreshSealed()
	for _, part in cacheParts do
		local cacheId = part:GetAttribute("CacheId")
		local cache = if type(cacheId) == "string" then World.cacheById[cacheId] else nil
		if cache ~= nil then
			showSealed(part, isSealed(cache.relicId))
		end
	end
end

-- Opens the cache at `part` for `player` and returns the code. A held cache is only opened
-- by a hold the server saw begin and last long enough.
local function open(player: Player, part: BasePart): string
	local cacheId = part:GetAttribute("CacheId")
	local cache = if type(cacheId) == "string" then World.cacheById[cacheId] else nil
	if cache == nil then
		return "CACHE_EMPTY"
	end

	-- No yielding call between tryCollect and storing the new state.
	local now = os.clock()
	local byPlayer = holds[part]
	local h = if byPlayer ~= nil then byPlayer[player] else nil
	local hold = if cache.hold ~= nil and cache.hold > 0 then cache.hold else nil
	local began = if h ~= nil then h.began else nil
	local ended = if h ~= nil then h.ended else nil
	local holdOk = Sources.holdOk(hold, began, ended, now)
	if byPlayer ~= nil then
		byPlayer[player] = nil
	end
	local newState, newLedger, code, availableAt = Sources.tryCollect(
		state,
		LedgerService.get(player),
		cache,
		now,
		distanceToPlayer(player, part),
		isSealed(cache.relicId),
		LedgerService.isLocked(player),
		holdOk
	)
	if newLedger == nil or availableAt == nil then
		LedgerService.notify(player, code)
		return code
	end
	if not LedgerService.set(player, newLedger) then
		-- The data went away; the cache stays as it was.
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return "DATA_NOT_LOADED"
	end
	state = newState
	-- The cache is empty now: nobody's hold on it counts for the next opening.
	holds[part] = nil
	local relic = Relics.byId[cache.relicId]
	LedgerService.notify(player, code, { name = if relic ~= nil then relic.name else "" })

	setVisible(part, false)
	task.delay(availableAt - now, setVisible, part, true)
	return code
end

-- Play-test seam: the prompt's path with no hold record. Returns the code ("CACHE_EMPTY" when
-- no cache part has that id).
function SourceService.tryOpen(player: Player, cacheId: string): string
	for _, part in cacheParts do
		if part:GetAttribute("CacheId") == cacheId then
			return open(player, part)
		end
	end
	return "CACHE_EMPTY"
end

local function dropHolds(player: Player)
	for _, byPlayer in holds do
		byPlayer[player] = nil
	end
end

-- Drops a hold once the player is dead, gone or out of reach of the part.
local function sweepHolds()
	for part, byPlayer in holds do
		for player in byPlayer do
			local _, root = Fighters.body(player.UserId)
			if
				player.Parent == nil
				or root == nil
				or (root.Position - part.Position).Magnitude > Sources.MAX_DISTANCE
			then
				byPlayer[player] = nil
			end
		end
	end
end

local function connect(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if prompt == nil then
		return
	end
	table.insert(cacheParts, part)
	prompt.PromptButtonHoldBegan:Connect(function(player: Player)
		local byPlayer = holds[part]
		if byPlayer == nil then
			byPlayer = {}
			holds[part] = byPlayer
		end
		byPlayer[player] = { began = os.clock() }
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player: Player)
		local byPlayer = holds[part]
		local h = if byPlayer ~= nil then byPlayer[player] else nil
		if h ~= nil and h.ended == nil then
			h.ended = os.clock()
		end
	end)
	prompt.Triggered:Connect(function(player: Player)
		open(player, part)
	end)
end

-- Sends the player their CoinSync again (the client asked for its state). Nothing until loaded.
function SourceService.resync(player: Player)
	local data = DataService.get(player)
	if data ~= nil and player.Parent == Players then
		coinSync:FireClient(player, data.coin)
	end
end

function SourceService.start()
	coinSync = LedgerService.makeRemote(Net.CoinSync)
	DataService.onLoaded(function(player, data)
		if player.Parent == Players then
			coinSync:FireClient(player, data.coin)
		end
	end)
	LedgerService.onRequest(SourceService.resync)

	for _, instance in CollectionService:GetTagged("Cache") do
		connect(instance)
	end

	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			dropHolds(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			sweepHolds()
		end
	end)

	LedgerService.onChanged(refreshSealed)
	DataService.onLoaded(refreshSealed)
	Players.PlayerRemoving:Connect(function(player)
		dropHolds(player)
		-- One frame later, once the leaving player's data is gone (held players stay counted).
		task.defer(refreshSealed)
	end)
	refreshSealed()
end

return SourceService
