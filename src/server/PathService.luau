--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Catalog.Abilities)
local Loadout = require(ReplicatedStorage.Shared.Rules.Loadout)
local Net = require(ReplicatedStorage.Shared.Net)
local PathProgress = require(ReplicatedStorage.Shared.Rules.PathProgress)
local Protection = require(ReplicatedStorage.Shared.Rules.Protection)
local RateLimiter = require(ReplicatedStorage.Shared.Rules.RateLimiter)
local Types = require(ReplicatedStorage.Shared.Types)
local ClaimService = require(script.Parent.ClaimService)
local DataService = require(script.Parent.DataService)
local LedgerService = require(script.Parent.LedgerService)

type PathProgress = Types.PathProgress

local BUCKET_CAPACITY = 10
local BUCKET_REFILL_PER_SECOND = 5
local DEFEAT_XP = 150
local SECONDS_PER_DAY = 86400

local PathService = {}

local buckets: { [Player]: RateLimiter.Bucket } = {}
local changedCallbacks: { (player: Player, progress: PathProgress) -> () } = {}
local pathSync: RemoteEvent

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

local function sync(player: Player, data: Types.PlayerData)
	if player.Parent ~= Players then
		return
	end
	pathSync:FireClient(player, data.paths, data.coin, os.time())
end

-- The player's saved Path progress, or nil until loaded and after they left.
function PathService.get(player: Player): PathProgress?
	local data = DataService.get(player)
	if data == nil then
		return nil
	end
	return data.paths
end

function PathService.onChanged(callback: (player: Player, progress: PathProgress) -> ())
	table.insert(changedCallbacks, callback)
end

local function fireChanged(player: Player, progress: PathProgress)
	for _, callback in changedCallbacks do
		local ok, err = pcall(callback, player, progress)
		if not ok then
			warn(`[IsleOfAvarice] onChanged callback failed: {err}`)
		end
	end
end

local function abilityName(id: string): string
	local ability = Abilities.byId[id]
	return if ability ~= nil then ability.name else id
end

-- Adds Path XP at the learning rate for the player's Calling. Does nothing for a player whose
-- data is not loaded or who has left. No yielding call between the read and the write.
function PathService.grant(player: Player, path: string, base: number)
	if player.Parent ~= Players then
		return
	end
	local data = DataService.get(player)
	if data == nil then
		return
	end
	local newProgress, gained, levelsGained, unlocked = PathProgress.addXp(data.paths, path, base)
	if not (gained > 0) then
		return
	end
	newProgress = Loadout.autoFill(newProgress, unlocked)
	data.paths = newProgress

	if levelsGained > 0 then
		LedgerService.notify(player, "LEVEL_UP", {
			path = path,
			level = tostring(PathProgress.level(newProgress, path)),
		})
	end
	for _, id in unlocked do
		LedgerService.notify(player, "ABILITY_UNLOCKED", { name = abilityName(id) })
	end
	sync(player, data)
	fireChanged(player, newProgress)
end

local function handlePick(player: Player, pathId: any)
	if player.Parent ~= Players or not allowed(player) then
		return
	end
	local data = DataService.get(player)
	if data == nil then
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return
	end
	local newProgress, code, unlocked = PathProgress.chooseCalling(data.paths, pathId)
	if newProgress == nil then
		LedgerService.notify(player, code)
		return
	end
	data.paths = Loadout.autoFill(newProgress, unlocked)
	LedgerService.notify(player, "CALLING_CHOSEN", { path = newProgress.calling })
	sync(player, data)
	fireChanged(player, data.paths)
end

local function handleChange(player: Player, pathId: any)
	if player.Parent ~= Players or not allowed(player) then
		return
	end
	local data = DataService.get(player)
	if data == nil then
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return
	end
	local now = os.time()
	local newProgress, code, cost = PathProgress.changeCalling(data.paths, pathId, data.coin, now)
	if newProgress == nil then
		if code == "CALLING_COOLDOWN" then
			local left = data.paths.callingChangedAt + PathProgress.CHANGE_COOLDOWN - now
			LedgerService.notify(
				player,
				code,
				{ days = tostring(math.max(1, math.ceil(left / SECONDS_PER_DAY))) }
			)
		elseif code == "NOT_ENOUGH_COIN" then
			LedgerService.notify(player, code, { cost = tostring(PathProgress.CHANGE_COST) })
		else
			LedgerService.notify(player, code)
		end
		return
	end
	data.coin = data.coin - cost
	data.paths = newProgress
	LedgerService.notify(player, "CALLING_CHANGED", { path = newProgress.calling })
	sync(player, data)
	fireChanged(player, newProgress)
end

local function handleLoadout(player: Player, request: any)
	if player.Parent ~= Players or not allowed(player) then
		return
	end
	local data = DataService.get(player)
	local newProgress, code =
		Loadout.apply(if data ~= nil then data.paths else nil, request, playerInSafeZone(player))
	if newProgress == nil or data == nil then
		LedgerService.notify(player, code)
		return
	end
	data.paths = newProgress
	LedgerService.notify(player, code)
	sync(player, data)
	fireChanged(player, newProgress)
end

function PathService.start()
	pathSync = LedgerService.makeRemote(Net.PathSync)
	LedgerService.makeRemote(Net.PickCalling).OnServerEvent:Connect(handlePick)
	LedgerService.makeRemote(Net.ChangeCalling).OnServerEvent:Connect(handleChange)
	LedgerService.makeRemote(Net.LoadoutAction).OnServerEvent:Connect(handleLoadout)

	DataService.onLoaded(function(player, data)
		sync(player, data)
	end)

	ClaimService.onClaimStarted(function(killer)
		local progress = PathService.get(killer)
		if progress ~= nil and progress.calling ~= "" then
			PathService.grant(killer, progress.calling, DEFEAT_XP)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return PathService
