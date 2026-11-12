--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Rules.Combat)
local Effects = require(ReplicatedStorage.Shared.Rules.Effects)
local Net = require(ReplicatedStorage.Shared.Net)
local Protection = require(ReplicatedStorage.Shared.Rules.Protection)
local Types = require(ReplicatedStorage.Shared.Types)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)
local LedgerService = require(script.Parent.LedgerService)
local ProtectionService = require(script.Parent.ProtectionService)
local Sight = require(script.Parent.Sight)
local StatusService = require(script.Parent.StatusService)

-- `path`: the Path a post hit trains ("Strike" = the attacker's Calling, "" = none).
type DamageOpts = { reflected: boolean?, tick: boolean?, passive: boolean?, path: string? }

local STRIKE_PATH = "Strike"
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
-- Last paid hit per attacker fighter id per post id, on os.clock().
local postHits: { [number]: { [number]: number } } = {}
local postBaseColor: { [BasePart]: Color3 } = {}
local postFlashToken: { [BasePart]: number } = {}

-- PathService.get and PathService.grant, passed in by Main.server.luau. PathService
-- requires ClaimService, which requires this module, so requiring it here would be a cycle.
local getPaths: ((Player) -> Types.PathProgress?)? = nil
local grantXp: ((Player, string, number) -> ())? = nil

-- A short flash on the post part. A newer flash takes over the restore.
local function flashPost(postId: number)
	local model = Fighters.model(postId)
	if model == nil or not model:IsA("BasePart") or not model:IsDescendantOf(workspace) then
		return
	end
	local part = model :: BasePart
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
	local entry = Fighters.get(killerId)
	local killer = if entry ~= nil then entry.player else nil
	if killer ~= nil and killer ~= victim then
		fireDefeat(killer, victim)
	end
end

-- A player hits a training post: Path XP, at most once per POST_XP_GAP per post per attacker,
-- and a flash. Posts have no protections and take no damage or effects. "Strike" trains the
-- attacker's Calling; without a Path (or a Calling) nothing happens.
local function hitPost(
	attacker: Player,
	attackerId: number,
	postId: number,
	opts: DamageOpts?
): boolean
	local path = if opts ~= nil and opts.path ~= nil then opts.path else ""
	if path == STRIKE_PATH then
		local paths = getPaths
		local progress = if paths ~= nil then paths(attacker) else nil
		path = if progress ~= nil then progress.calling else ""
	end
	if path == "" then
		return true
	end
	flashPost(postId)
	local now = os.clock()
	local hits = postHits[attackerId]
	if hits == nil then
		hits = {}
		postHits[attackerId] = hits
	end
	local last = hits[postId]
	-- Written so a NaN time pays nothing.
	if last ~= nil and not (now - last >= POST_XP_GAP) then
		return true
	end
	hits[postId] = now
	local grant = grantXp
	if grant ~= nil then
		grant(attacker, path, POST_XP)
	end
	return true
end

-- Player versus player: protections, Mark, empower, statuses, the hit log and the reflect.
local function damagePlayer(
	attacker: Player,
	victim: Player,
	amount: number,
	opts: DamageOpts?
): boolean
	local reflected = opts ~= nil and opts.reflected == true
	local tick = opts ~= nil and opts.tick == true
	local passive = opts ~= nil and opts.passive == true
	local victimHumanoid = Fighters.body(victim.UserId)
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
		StatusService.update(attacker.UserId, function(status, at)
			local out, taken = Effects.takeEmpower(status, at)
			bonus = taken
			return out
		end)
		total += bonus
	end

	local immune, health, reflectBack = false, 0, 0
	StatusService.update(victim.UserId, function(status, at)
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
	CombatService.flash(victim.UserId)

	-- A player the hit defeated reflects nothing.
	if reflectBack > 0 and not reflected and victimHumanoid.Health > 0 then
		CombatService.damage(victim.UserId, attacker.UserId, reflectBack, { reflected = true })
	end
	return true
end

-- HitFx to every client for the fighter `id`.
function CombatService.flash(id: number)
	hitFx:FireAllClients(id)
end

-- Damage from the island: no attacker, no protections (shields guard against players only),
-- no hit-log entry. The victim's own effects still apply: immunity cancels it; damage
-- reduction and ability shields absorb. Sets Humanoid.Health directly, so a ForceField does
-- not block it. `flash` also fires the HitFx remote. True when health was removed.
function CombatService.environmentDamage(victim: Player, amount: number, flash: boolean?): boolean
	-- Written positively so a NaN amount is refused too.
	if not (amount > 0) or victim.Parent ~= Players then
		return false
	end
	local humanoid = Fighters.body(victim.UserId)
	if humanoid == nil then
		return false
	end

	-- No yielding call from here to the health change: statuses cannot go stale.
	local immune, health = false, 0
	StatusService.update(victim.UserId, function(status, at)
		immune = Effects.isImmune(status, at)
		-- The reflect amount is dropped: the island has nothing to reflect at.
		local out, toHealth = Effects.resolveDamage(status, amount, at)
		health = toHealth
		return out
	end)
	if immune and not (health > 0) then
		return false
	end

	-- Not TakeDamage: a ForceField blocks that, and a shielded player is still hurt by the island.
	-- A defeat here is credited by the Died handler like any other.
	if health > 0 then
		humanoid.Health = math.max(0, humanoid.Health - health)
	end
	if flash == true then
		CombatService.flash(victim.UserId)
	end
	return health > 0
end

-- Defeats the victim outright (drowning). Ignores effects. The Died handler credits it.
function CombatService.environmentDefeat(victim: Player)
	if victim.Parent ~= Players then
		return
	end
	local humanoid = Fighters.body(victim.UserId)
	if humanoid ~= nil then
		humanoid.Health = 0
	end
end

-- The one way any fighter is hurt: the Strike, abilities, burns, zones and reflects, between
-- any two fighters in the registry that may fight. True only when the hit landed (a post
-- always counts; a player hit passed the protections and the victim was not immune); callers
-- apply statuses, pulls and knockbacks only then.
-- `reflected`: damage sent back by a reflect, so no protections, Mark or empower.
-- `tick`: burn or zone damage, so refusals are not notified and no empower is used.
-- `passive`: a zone tick on someone who walked in after it was placed; the damage and the
-- protections are unchanged, but the attacker is not Marked and keeps their respawn shield.
-- `path`: the Path a post hit trains ("Strike" = the attacker's Calling).
function CombatService.damage(
	attackerId: number,
	targetId: number,
	amount: number,
	opts: DamageOpts?
): boolean
	local attacker, target = Fighters.get(attackerId), Fighters.get(targetId)
	if attacker == nil or target == nil or not Fighters.mayFight(attackerId, targetId) then
		return false
	end
	local attackerPlayer = attacker.player
	if attacker.kind ~= "player" or attackerPlayer == nil then
		-- Creature attackers: Task 9.
		return false
	end
	if target.kind == "post" then
		return hitPost(attackerPlayer, attackerId, targetId, opts)
	end
	local victimPlayer = target.player
	if target.kind == "player" and victimPlayer ~= nil then
		return damagePlayer(attackerPlayer, victimPlayer, amount, opts)
	end
	-- Creature targets: Task 9.
	return false
end

-- The client only says "I swung". Target, reach, damage and timing are all decided here.
local function handleStrike(player: Player)
	if player.Parent ~= Players then
		return
	end
	local attacker = Fighters.fighter(player.UserId)
	if attacker == nil then
		return
	end
	local now = os.clock()
	if not Combat.canStrike(lastStrike[player], now) then
		return
	end
	lastStrike[player] = now

	-- Only what the attacker can see is a candidate, so a target behind a corner never
	-- swallows the swing, and an unseen taunter forces nothing.
	local p = attacker.position
	local others = Sight.filter(Vector3.new(p.x, p.y, p.z), Fighters.list(player.UserId))
	local taunter = Effects.tauntedBy(StatusService.get(player.UserId), now)
	local targetId = Combat.pickTarget(attacker, others, nil, taunter)
	if targetId == nil then
		return
	end
	-- A post trains the Calling; without a Calling the swing does nothing there.
	CombatService.damage(player.UserId, targetId, Combat.STRIKE_DAMAGE, { path = STRIKE_PATH })
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
		postHits[player.UserId] = nil
	end)
end

return CombatService
