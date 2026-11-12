--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Rules.Combat)
local Effects = require(ReplicatedStorage.Shared.Rules.Effects)
local Net = require(ReplicatedStorage.Shared.Net)
local Protection = require(ReplicatedStorage.Shared.Rules.Protection)
local Types = require(ReplicatedStorage.Shared.Types)
local World = require(ReplicatedStorage.Shared.Catalog.World)
local DataService = require(script.Parent.DataService)
local LedgerService = require(script.Parent.LedgerService)
local ProtectionService = require(script.Parent.ProtectionService)
local Sight = require(script.Parent.Sight)
local StatusService = require(script.Parent.StatusService)

type DamageOpts = { reflected: boolean?, tick: boolean?, passive: boolean? }

local POST_TAG = "TrainingPost"
local POST_XP = 10
local POST_XP_GAP = 0.5 -- seconds between paid hits, per post per attacker
local POST_FLASH_SECONDS = 0.15
local POST_FLASH_COLOR = Color3.fromRGB(255, 235, 150)

local CombatService = {}

-- Who last hit whom, keyed by victim UserId. Time from os.clock().
local hitLog: Combat.HitLog = {}
local lastStrike: { [Player]: number } = {}
local defeatCallbacks: { (killer: Player, victim: Player) -> () } = {}
local hitFx: RemoteEvent
-- Last paid hit per attacker per post id, on os.clock().
local postHits: { [Player]: { [number]: number } } = {}
local postBaseColor: { [BasePart]: Color3 } = {}
local postFlashToken: { [BasePart]: number } = {}

-- PathService.get and PathService.grant, passed in by Main.server.luau. PathService
-- requires ClaimService, which requires this module, so requiring it here would be a cycle.
local getPaths: ((Player) -> Types.PathProgress?)? = nil
local grantXp: ((Player, string, number) -> ())? = nil

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

local function fighterOf(id: number, root: BasePart, health: number?): Combat.Fighter
	local p = root.Position
	local look = root.CFrame.LookVector
	return {
		id = id,
		position = { x = p.X, y = p.Y, z = p.Z },
		look = { x = look.X, y = look.Y, z = look.Z },
		health = health,
	}
end

-- Every training post part in the world, by post id.
local function postParts(): { [number]: BasePart }
	local parts: { [number]: BasePart } = {}
	for _, instance in CollectionService:GetTagged(POST_TAG) do
		local id = instance:GetAttribute("PostId")
		if
			instance:IsA("BasePart")
			and instance:IsDescendantOf(workspace)
			and type(id) == "number"
			and World.postIndex(id) ~= nil
		then
			parts[id] = instance
		end
	end
	return parts
end

-- A short flash on the post part. A newer flash takes over the restore.
local function flashPost(postId: number)
	local part = postParts()[postId]
	if part == nil then
		return
	end
	local base = postBaseColor[part] or part.Color
	postBaseColor[part] = base
	local token = (postFlashToken[part] or 0) + 1
	postFlashToken[part] = token
	part.Color = POST_FLASH_COLOR
	task.delay(POST_FLASH_SECONDS, function()
		if postFlashToken[part] == token then
			part.Color = base
		end
	end)
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

function CombatService.isPost(id: number): boolean
	return World.postIndex(id) ~= nil
end

-- Every other living player's fighter (with health) plus every training post, and a map
-- from player fighter id (UserId) to the Player.
function CombatService.fighters(except: Player): ({ Combat.Fighter }, { [number]: Player })
	local list: { Combat.Fighter } = {}
	local byId: { [number]: Player } = {}
	for _, other in Players:GetPlayers() do
		if other == except then
			continue
		end
		local humanoid, root = living(other)
		if humanoid ~= nil and root ~= nil then
			table.insert(list, fighterOf(other.UserId, root, humanoid.Health))
			byId[other.UserId] = other
		end
	end
	local parts = postParts()
	for i = 1, #World.trainingPosts do
		local id = World.POST_ID_BASE - i
		local part = parts[id]
		if part ~= nil then
			local p = part.Position
			table.insert(list, {
				id = id,
				position = { x = p.X, y = p.Y, z = p.Z },
				look = { x = 0, y = 0, z = 1 },
			})
		end
	end
	return list, byId
end

-- Path XP for hitting a training post: at most once per POST_XP_GAP per post per attacker.
-- Posts have no protections. Callers pass the Path to train; nothing is paid without one.
function CombatService.hitPost(attacker: Player, postId: number, path: string)
	if attacker.Parent ~= Players or World.postIndex(postId) == nil then
		return
	end
	flashPost(postId)
	local now = os.clock()
	local hits = postHits[attacker]
	if hits == nil then
		hits = {}
		postHits[attacker] = hits
	end
	local last = hits[postId]
	-- Written so a NaN time pays nothing.
	if last ~= nil and not (now - last >= POST_XP_GAP) then
		return
	end
	hits[postId] = now
	local grant = grantXp
	if grant ~= nil then
		grant(attacker, path, POST_XP)
	end
end

-- The one way a player takes damage: the Strike, abilities, burns, zones and reflects.
-- True only when the hit landed (it passed the protections and the victim was not immune);
-- callers apply statuses, pulls and knockbacks only then.
-- `reflected`: damage sent back by a reflect, so no protections, Mark or empower.
-- `tick`: burn or zone damage, so refusals are not notified and no empower is used.
-- `passive`: a zone tick on someone who walked in after it was placed; the damage and the
-- protections are unchanged, but the attacker is not Marked and keeps their respawn shield.
function CombatService.damage(
	attacker: Player,
	victim: Player,
	amount: number,
	opts: DamageOpts?
): boolean
	local reflected = opts ~= nil and opts.reflected == true
	local tick = opts ~= nil and opts.tick == true
	local passive = opts ~= nil and opts.passive == true
	if attacker == victim or attacker.Parent ~= Players or victim.Parent ~= Players then
		return false
	end
	local victimHumanoid = living(victim)
	if victimHumanoid == nil then
		return false
	end
	local now = os.clock()

	-- No yielding call from here to TakeDamage: statuses cannot go stale.
	if not reflected then
		local attackerStatus = ProtectionService.status(attacker, now)
		if attackerStatus == nil then
			-- A living attacker without loaded data is told; one without a living character
			-- (a burn or zone outliving its owner) cannot pass the protections either.
			if not tick and DataService.get(attacker) == nil then
				LedgerService.notify(attacker, "DATA_NOT_LOADED")
			end
			return false
		end
		local victimStatus = ProtectionService.status(victim, now)
		if victimStatus == nil then
			-- Victim's data is not loaded yet: treat them as shielded.
			if not tick then
				LedgerService.notify(attacker, "TARGET_SHIELDED")
			end
			return false
		end
		local ok, code = Protection.canDamage(attackerStatus, victimStatus, now)
		if not ok then
			if not tick then
				LedgerService.notify(attacker, code or "BAD_REQUEST")
			end
			return false
		end

		-- A passive hit (a zone on someone who walked into it) starts no fight for its owner.
		if not passive then
			ProtectionService.endRespawnShield(attacker)
			local victimMarked = Protection.isMarked(victimStatus, now)
			if
				Protection.isAggressor(hitLog, attacker.UserId, victim.UserId, victimMarked, now)
			then
				ProtectionService.mark(attacker, now)
			end
		end
	end

	local total = amount
	if not reflected and not tick then
		local bonus = 0
		StatusService.update(attacker, function(status, at)
			local out, taken = Effects.takeEmpower(status, at)
			bonus = taken
			return out
		end)
		total += bonus
	end

	local immune, health, reflectBack = false, 0, 0
	StatusService.update(victim, function(status, at)
		immune = Effects.isImmune(status, at)
		local out, toHealth, toReflect = Effects.resolveDamage(status, total, at)
		health, reflectBack = toHealth, toReflect
		return out
	end)
	if immune and not (health > 0) then
		return false
	end

	-- Record the hit before the damage: with immediate signal behaviour, Died can fire
	-- inside TakeDamage, and the kill must already be credited by then.
	hitLog = Combat.recordHit(hitLog, victim.UserId, attacker.UserId, now)
	if health > 0 then
		victimHumanoid:TakeDamage(health)
	end
	hitFx:FireAllClients(victim.UserId)

	-- A player the hit defeated reflects nothing.
	if reflectBack > 0 and not reflected and victimHumanoid.Health > 0 then
		CombatService.damage(victim, attacker, reflectBack, { reflected = true })
	end
	return true
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

	-- Only what the attacker can see is a candidate, so a target behind a corner never
	-- swallows the swing, and an unseen taunter forces nothing.
	local all, byId = CombatService.fighters(player)
	local others = Sight.filter(attackerRoot.Position, all)
	local taunter = Effects.tauntedBy(StatusService.get(player), now)
	local targetId = Combat.pickTarget(fighterOf(player.UserId, attackerRoot), others, nil, taunter)
	if targetId == nil then
		return
	end

	if CombatService.isPost(targetId) then
		-- A post trains the Calling; without a Calling the swing does nothing.
		local paths = getPaths
		local progress = if paths ~= nil then paths(player) else nil
		if progress ~= nil and progress.calling ~= "" then
			CombatService.hitPost(player, targetId, progress.calling)
		end
		return
	end

	local victim = byId[targetId]
	if victim == nil then
		return
	end
	CombatService.damage(player, victim, Combat.STRIKE_DAMAGE)
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

-- `paths` and `grant` are PathService.get and PathService.grant (see getPaths above).
function CombatService.start(
	paths: (Player) -> Types.PathProgress?,
	grant: (Player, string, number) -> ()
)
	getPaths = paths
	grantXp = grant
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
		postHits[player] = nil
	end)
end

return CombatService
