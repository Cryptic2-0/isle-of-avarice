--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Rules.Combat)
local Net = require(ReplicatedStorage.Shared.Net)
local Protection = require(ReplicatedStorage.Shared.Rules.Protection)
local DataService = require(script.Parent.DataService)
local LedgerService = require(script.Parent.LedgerService)
local ProtectionService = require(script.Parent.ProtectionService)

local CombatService = {}

-- Who last hit whom, keyed by victim UserId. Time from os.clock().
local hitLog: Combat.HitLog = {}
local lastStrike: { [Player]: number } = {}
local defeatCallbacks: { (killer: Player, victim: Player) -> () } = {}
local hitFx: RemoteEvent

-- The Humanoid and HumanoidRootPart of a living character, or nil.
local function living(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root
end

local function fighterOf(id: number, root: BasePart): Combat.Fighter
	local p = root.Position
	local look = root.CFrame.LookVector
	return {
		id = id,
		position = { x = p.X, y = p.Y, z = p.Z },
		look = { x = look.X, y = look.Y, z = look.Z },
	}
end

-- Runs every defeat callback now, in this thread, so a callback can take a DataService hold
-- inside PlayerRemoving before the leaver's profile is released.
local function fireDefeat(killer: Player, victim: Player)
	for _, callback in defeatCallbacks do
		local ok, err = pcall(callback, killer, victim)
		if not ok then
			warn(`[IsleOfAvarice] onDefeat callback failed: {err}`)
		end
	end
end

-- Gives the kill to whoever hit the victim within the window, if they are still here.
local function creditDefeat(victim: Player, windowSeconds: number)
	local now = os.clock()
	local killerId = Combat.creditFor(hitLog, victim.UserId, now, windowSeconds)
	hitLog = Combat.clear(hitLog, victim.UserId)
	if killerId == nil then
		return
	end
	local killer = Players:GetPlayerByUserId(killerId)
	if killer ~= nil and killer ~= victim then
		fireDefeat(killer, victim)
	end
end

-- The client only says "I swung". Target, reach, damage and timing are all decided here.
local function handleStrike(player: Player)
	if player.Parent ~= Players then
		return
	end
	local _, attackerRoot = living(player)
	if attackerRoot == nil then
		return
	end
	local now = os.clock()
	if not Combat.canStrike(lastStrike[player], now) then
		return
	end
	lastStrike[player] = now

	local others: { Combat.Fighter } = {}
	local byId: { [number]: { player: Player, humanoid: Humanoid } } = {}
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local humanoid, root = living(other)
		if humanoid ~= nil and root ~= nil then
			table.insert(others, fighterOf(other.UserId, root))
			byId[other.UserId] = { player = other, humanoid = humanoid }
		end
	end

	local targetId = Combat.pickTarget(fighterOf(player.UserId, attackerRoot), others)
	if targetId == nil then
		return
	end
	local target = byId[targetId]
	if target == nil then
		return
	end
	local victim = target.player

	-- No yielding call from here to TakeDamage: statuses cannot go stale.
	local attackerStatus = ProtectionService.status(player, now)
	if attackerStatus == nil then
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return
	end
	local victimStatus = ProtectionService.status(victim, now)
	if victimStatus == nil then
		-- Victim's data is not loaded yet: treat them as shielded.
		LedgerService.notify(player, "TARGET_SHIELDED")
		return
	end
	local ok, code = Protection.canDamage(attackerStatus, victimStatus, now)
	if not ok then
		LedgerService.notify(player, code or "BAD_REQUEST")
		return
	end

	ProtectionService.endRespawnShield(player)
	local victimMarked = Protection.isMarked(victimStatus, now)
	if Protection.isAggressor(hitLog, player.UserId, victim.UserId, victimMarked, now) then
		ProtectionService.mark(player, now)
	end
	-- Record the hit before the damage: with immediate signal behaviour, Died can fire
	-- inside TakeDamage, and the kill must already be credited by then.
	hitLog = Combat.recordHit(hitLog, victim.UserId, player.UserId, now)
	target.humanoid:TakeDamage(Combat.STRIKE_DAMAGE)
	hitFx:FireAllClients(victim.UserId)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.MaxHealth = Combat.MAX_HEALTH
	humanoid.Health = Combat.MAX_HEALTH
	humanoid.Died:Connect(function()
		creditDefeat(player, Combat.KILL_CREDIT_SECONDS)
	end)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	local character = player.Character
	if character ~= nil then
		task.spawn(onCharacterAdded, player, character)
	end
end

-- Player-versus-player defeats, and leaving within the combat-log window after being hit.
function CombatService.onDefeat(callback: (killer: Player, victim: Player) -> ())
	table.insert(defeatCallbacks, callback)
end

function CombatService.start()
	hitFx = LedgerService.makeRemote(Net.HitFx)
	local strike = LedgerService.makeRemote(Net.Strike)
	strike.OnServerEvent:Connect(handleStrike)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	-- Combat log: leaving soon after being hit counts as a defeat.
	DataService.beforeRelease(function(player)
		creditDefeat(player, Combat.COMBAT_LOG_SECONDS)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastStrike[player] = nil
	end)
end

return CombatService
