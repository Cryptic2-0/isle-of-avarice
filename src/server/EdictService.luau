--!strict
-- The five Edicts (spec 3.13): using one from a free slot, the Veil, who has met whom, and
-- what a defeat destroys. EdictRules holds every rule; this service gathers the facts, checks
-- each request itself (who, where, when, whether they hold the card) and applies the result.
-- Veil and "met" are session state and never saved. No yielding call sits between reading a
-- Ledger and writing it back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cards = require(ReplicatedStorage.Shared.Catalog.Cards)
local EdictRules = require(ReplicatedStorage.Shared.Rules.EdictRules)
local Geography = require(ReplicatedStorage.Shared.Rules.Geography)
local Hazards = require(ReplicatedStorage.Shared.Rules.Hazards)
local Ledger = require(ReplicatedStorage.Shared.Rules.Ledger)
local Net = require(ReplicatedStorage.Shared.Net)
local Protection = require(ReplicatedStorage.Shared.Rules.Protection)
local RateLimiter = require(ReplicatedStorage.Shared.Rules.RateLimiter)
local Sites = require(ReplicatedStorage.Shared.Catalog.Sites)
local Types = require(ReplicatedStorage.Shared.Types)
local World = require(ReplicatedStorage.Shared.Catalog.World)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)
local LedgerService = require(script.Parent.LedgerService)
local ProtectionService = require(script.Parent.ProtectionService)
local TrialService = require(script.Parent.TrialService)

local BUCKET_CAPACITY = 10
local BUCKET_REFILL_PER_SECOND = 5
local MEET_TICK_SECONDS = 1
local HOMECOMING_LIFT = 4 -- above the spawn pad, so the character lands on it

local EdictService = {}

-- When each player's Veil ends, on os.clock().
local veilUntil: { [Player]: number } = {}
-- Who has come within MEET_RANGE of whom. Always set both ways.
local met: { [Player]: { [Player]: boolean } } = {}
local buckets: { [Player]: RateLimiter.Bucket } = {}
local resultRemote: RemoteEvent
local syncRemote: RemoteEvent
local accumulated = 0
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

local function vec(position: Vector3): Types.Vec3
	return { x = position.X, y = position.Y, z = position.Z }
end

function EdictService.isVeiled(player: Player): boolean
	return EdictRules.isVeiled(veilUntil[player], os.clock())
end

-- Veil seconds left and the players this one has met who are still here, by name.
local function sync(player: Player)
	if player.Parent ~= Players then
		return
	end
	local list: { { userId: number, name: string } } = {}
	local others = met[player]
	if others ~= nil then
		for other in others do
			if other.Parent == Players then
				table.insert(list, { userId = other.UserId, name = other.DisplayName })
			end
		end
	end
	table.sort(list, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.userId < b.userId
	end)
	syncRemote:FireClient(player, EdictRules.veilSeconds(veilUntil[player], os.clock()), list)
end

-- Marks the two as having met. True when it was new for either side.
local function markMet(a: Player, b: Player): boolean
	local fresh = false
	local aMet = met[a]
	if aMet == nil then
		aMet = {}
		met[a] = aMet
	end
	if not aMet[b] then
		aMet[b] = true
		fresh = true
	end
	local bMet = met[b]
	if bMet == nil then
		bMet = {}
		met[b] = bMet
	end
	if not bMet[a] then
		bMet[a] = true
		fresh = true
	end
	return fresh
end

-- Play-test seam: marks the two as having met.
function EdictService.meet(a: Player, b: Player)
	if markMet(a, b) then
		sync(a)
		sync(b)
	end
end

-- Play-test seam: the defeat-loss rolls (default math.random).
function EdictService.setRng(roll: () -> number)
	rng = roll
end

-- Once a second: every pair of living players within MEET_RANGE has met.
local function meetTick()
	local present: { { player: Player, position: Types.Vec3 } } = {}
	for _, player in Players:GetPlayers() do
		local _, root = Fighters.body(player.UserId)
		if root ~= nil then
			table.insert(present, { player = player, position = vec(root.Position) })
		end
	end
	for i = 1, #present do
		for j = i + 1, #present do
			local a, b = present[i], present[j]
			if EdictRules.near(a.position, b.position, EdictRules.MEET_RANGE) then
				EdictService.meet(a.player, b.player)
			end
		end
	end
end

-- Passage and Homecoming. Not while Marked, in a fight, or in a trial; a player with no
-- loaded data or no living body is not told anything more than "not now".
local function travelAllowed(player: Player, now: number): (boolean, string)
	local status = ProtectionService.status(player, now)
	if status == nil then
		return false, "EDICT_NOT_NOW"
	end
	local ok, code = EdictRules.canTravel({
		marked = Protection.isMarked(status, now),
		lastFightAt = CombatService.lastFightAt(player),
		inTrial = TrialService.run(player) ~= nil,
	}, now)
	return ok, code or "EDICT_NOT_NOW"
end

local function isClear(x: number, z: number): boolean
	if not Geography.isLand(x, z) then
		return false
	end
	for _, hazard in Sites.hazards do
		if Hazards.affects(hazard, x, z) then
			return false
		end
	end
	return true
end

local function moveRoot(root: BasePart, x: number, y: number, z: number)
	root.CFrame = CFrame.new(x, y, z) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero
end

-- The Ledger after the card is used up. Written in the same step as the effect.
local function consume(player: Player, ledger: Types.Ledger, use: EdictRules.Use)
	local after = Ledger.discard(ledger, use.freeIndex)
	if after ~= nil then
		LedgerService.set(player, after)
	end
end

local function useSummons(player: Player, ledger: Types.Ledger, use: EdictRules.Use)
	local relicId = use.relicId
	if relicId == nil then
		return
	end
	local people: { EdictRules.Person } = {}
	for _, other in Players:GetPlayers() do
		local data = DataService.get(other)
		if data ~= nil then
			table.insert(people, {
				userId = other.UserId,
				name = other.DisplayName,
				ledger = data.ledger,
				veiled = EdictService.isVeiled(other),
			})
		end
	end
	local names = EdictRules.holders(people, relicId, player.UserId)
	resultRemote:FireClient(player, EdictRules.summonsResult(relicId, names))
	consume(player, ledger, use)
end

local function useAudit(player: Player, root: BasePart, ledger: Types.Ledger, use: EdictRules.Use)
	local others: { EdictRules.Body } = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local _, otherRoot = Fighters.body(other.UserId)
			if otherRoot ~= nil then
				table.insert(others, { userId = other.UserId, position = vec(otherRoot.Position) })
			end
		end
	end
	local targetId =
		EdictRules.auditTarget({ userId = player.UserId, position = vec(root.Position) }, others)
	local target = if targetId ~= nil then Players:GetPlayerByUserId(targetId) else nil
	local targetData = if target ~= nil then DataService.get(target) else nil
	if target == nil or targetData == nil then
		LedgerService.notify(player, "EDICT_NO_TARGET")
		return
	end
	if EdictService.isVeiled(target) then
		resultRemote:FireClient(player, EdictRules.veiledResult(target.DisplayName))
	else
		resultRemote:FireClient(
			player,
			EdictRules.auditResult(target.DisplayName, targetData.ledger, targetData.vault)
		)
		LedgerService.notify(target, "AUDITED", { player = player.DisplayName })
	end
	consume(player, ledger, use)
end

local function useVeil(player: Player, ledger: Types.Ledger, use: EdictRules.Use)
	veilUntil[player] = os.clock() + EdictRules.VEIL_SECONDS
	LedgerService.notify(player, "EDICT_VEIL_ON")
	consume(player, ledger, use)
	sync(player)
end

local function usePassage(
	player: Player,
	root: BasePart,
	ledger: Types.Ledger,
	use: EdictRules.Use,
	now: number
)
	local targetId = use.targetId
	local entry = if targetId ~= nil then Fighters.get(targetId) else nil
	local target = if entry ~= nil and entry.kind == "player" then entry.player else nil
	local metSet = met[player]
	if target == nil or target == player or metSet == nil or not metSet[target] then
		LedgerService.notify(player, "EDICT_NOT_MET")
		return
	end
	local _, targetRoot = Fighters.body(target.UserId)
	if targetRoot == nil then
		LedgerService.notify(player, "EDICT_NO_TARGET")
		return
	end
	local ok, code = travelAllowed(player, now)
	if not ok then
		LedgerService.notify(player, code)
		return
	end
	local spot = EdictRules.arrival(vec(targetRoot.Position), isClear)
	moveRoot(root, spot.x, spot.y, spot.z)
	LedgerService.notify(player, "PASSAGE_DONE", { player = target.DisplayName })
	consume(player, ledger, use)
end

local function useHomecoming(
	player: Player,
	root: BasePart,
	ledger: Types.Ledger,
	use: EdictRules.Use,
	now: number
)
	local ok, code = travelAllowed(player, now)
	if not ok then
		LedgerService.notify(player, code)
		return
	end
	moveRoot(root, World.spawn.x, World.spawn.y + HOMECOMING_LIFT, World.spawn.z)
	LedgerService.notify(player, "HOMECOMING_DONE")
	consume(player, ledger, use)
end

-- The client names a card row and what it needs; everything else is checked here, in order:
-- present and not too fast, Ledger not locked, a valid request for a card actually held there,
-- a living body. Nothing changes on a refusal.
local function handleUse(player: Player, raw: any)
	if player.Parent ~= Players or not allowed(player) then
		return
	end
	if LedgerService.isLocked(player) then
		LedgerService.notify(player, "LEDGER_LOCKED")
		return
	end
	local ledger = LedgerService.get(player)
	local use, code = EdictRules.parseUse(ledger, raw)
	if use == nil or ledger == nil then
		LedgerService.notify(player, code)
		return
	end
	local humanoid, root = Fighters.body(player.UserId)
	if humanoid == nil or root == nil then
		LedgerService.notify(player, "EDICT_NOT_NOW")
		return
	end

	-- No yielding call from here to the Ledger write: the Ledger read cannot go stale.
	local now = os.clock()
	if use.key == "summons" then
		useSummons(player, ledger, use)
	elseif use.key == "audit" then
		useAudit(player, root, ledger, use)
	elseif use.key == "veil" then
		useVeil(player, ledger, use)
	elseif use.key == "passage" then
		usePassage(player, root, ledger, use, now)
	elseif use.key == "homecoming" then
		useHomecoming(player, root, ledger, use, now)
	end
end

-- A defeat destroys a third of the Edicts held (never Relics).
local function onDefeated(player: Player)
	if player.Parent ~= Players then
		return
	end
	local data = DataService.get(player)
	if data == nil then
		return
	end
	local after, lost = EdictRules.defeatLoss(data.ledger, rng)
	if #lost == 0 then
		return
	end
	if LedgerService.set(player, after) then
		LedgerService.notify(player, "EDICTS_LOST", { names = Cards.names(lost) })
	end
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Connect(function()
		onDefeated(player)
	end)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	local character = player.Character
	if character ~= nil then
		task.spawn(watchCharacter, player, character)
	end
end

local function onHeartbeat(deltaTime: number)
	accumulated += deltaTime
	if accumulated < MEET_TICK_SECONDS then
		return
	end
	accumulated = 0
	local ok, err = pcall(meetTick)
	if not ok then
		warn(`[IsleOfAvarice] EdictService meeting tick failed: {err}`)
	end
end

local function onRemoving(player: Player)
	veilUntil[player] = nil
	buckets[player] = nil
	met[player] = nil
	-- Everyone who had met them forgets them and is told.
	for other, others in met do
		if others[player] then
			others[player] = nil
			sync(other)
		end
	end
end

function EdictService.start()
	resultRemote = LedgerService.makeRemote(Net.EdictResult)
	syncRemote = LedgerService.makeRemote(Net.EdictSync)
	LedgerService.makeRemote(Net.EdictUse).OnServerEvent:Connect(handleUse)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	DataService.onLoaded(function(player)
		sync(player)
	end)
	Players.PlayerRemoving:Connect(onRemoving)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return EdictService
