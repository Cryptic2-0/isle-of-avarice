--!strict
-- Turns a client's "cast slot N" into the effects of the 18 abilities. The client names only
-- a slot: the ability, targets, damage, movement and timing are all decided here, from the pure
-- Casting plan and the server's own view of the world. Every hit (player or post) goes through
-- CombatService.damage, and a hit's statuses, pull or knockback follow only when it landed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Catalog.Abilities)
local Casting = require(ReplicatedStorage.Shared.Rules.Casting)
local Combat = require(ReplicatedStorage.Shared.Rules.Combat)
local CreatureBrain = require(ReplicatedStorage.Shared.Rules.CreatureBrain)
local Effects = require(ReplicatedStorage.Shared.Rules.Effects)
local Net = require(ReplicatedStorage.Shared.Net)
local Paths = require(ReplicatedStorage.Shared.Catalog.Paths)
local RateLimiter = require(ReplicatedStorage.Shared.Rules.RateLimiter)
local Targeting = require(ReplicatedStorage.Shared.Rules.Targeting)
local Types = require(ReplicatedStorage.Shared.Types)
local World = require(ReplicatedStorage.Shared.Catalog.World)
local CombatService = require(script.Parent.CombatService)
local Fighters = require(script.Parent.Fighters)
local Fx = require(script.Parent.Fx)
local LedgerService = require(script.Parent.LedgerService)
local PathService = require(script.Parent.PathService)
local Sight = require(script.Parent.Sight)
local StatusService = require(script.Parent.StatusService)

type Ability = Types.Ability
type Fighter = Combat.Fighter
type Plan = Casting.Plan
type Vec3 = Types.Vec3

local BUCKET_CAPACITY = 10
local BUCKET_REFILL_PER_SECOND = 5
local ZONE_WALL_MARGIN = 1 -- a zone's centre stops this far short of a wall
local RING_LIFT = 0.2 -- above the caster's feet
local DEFAULT_COLOR = Color3.fromRGB(200, 200, 200)

local AbilityService = {}

-- Cooldowns per player, on os.clock(). Kept across respawns, dropped when the player leaves.
local castStates: { [Player]: Casting.CastState } = {}
local buckets: { [Player]: RateLimiter.Bucket } = {}
local cooldownRemote: RemoteEvent

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

-- The Humanoid and HumanoidRootPart of a living character, or nil.
local function living(player: Player): (Humanoid?, BasePart?)
	return Fighters.body(player.UserId)
end

local function fighterOf(player: Player, humanoid: Humanoid, root: BasePart): Fighter
	local p = root.Position
	local look = root.CFrame.LookVector
	return {
		id = player.UserId,
		position = { x = p.X, y = p.Y, z = p.Z },
		look = { x = look.X, y = look.Y, z = look.Z },
		health = humanoid.Health,
	}
end

local function pathColor(path: string): Color3
	local info = Paths.info[path :: Types.PathId]
	if info == nil then
		return DEFAULT_COLOR
	end
	return Color3.fromRGB(info.color.r, info.color.g, info.color.b)
end

-- ---------------------------------------------------------------------------------------
-- World rays: movement (dash, pull, knockback) and line of sight
-- ---------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------
-- Effects on players
-- ---------------------------------------------------------------------------------------

local function heal(player: Player, amount: number)
	local humanoid = living(player)
	if humanoid == nil or not (amount > 0) then
		return
	end
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
end

-- Who a support effect reaches: the caster and the caster's allies (in M3 only the caster;
-- parties come later), each alive and, when the ability has an ally radius, within it.
local function alliesOf(player: Player, ability: Ability): { Player }
	local _, casterRoot = living(player)
	if casterRoot == nil then
		return {}
	end
	local reach = ability.allyRadius
	local result: { Player } = {}
	for _, ally in { player } do
		local _, allyRoot = living(ally)
		if allyRoot == nil then
			continue
		end
		if
			ally ~= player
			and reach ~= nil
			and not ((allyRoot.Position - casterRoot.Position).Magnitude <= reach)
		then
			continue
		end
		table.insert(result, ally)
	end
	return result
end

local function vector(v: Vec3): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

-- True when nothing solid stands between the caster and the fighter `targetId`: one ray from
-- the root position the plan was made from (for a dash, where it started) to the target's
-- root or post position.
local function inSight(caster: Fighter, others: { Fighter }, targetId: number): boolean
	for _, other in others do
		if other.id == targetId then
			local target = Fighters.model(targetId)
			return Sight.obstruction(vector(caster.position), vector(other.position), target) == nil
		end
	end
	return false
end

-- Applies a plan's hits. A hit the caster has no line of sight to is skipped entirely. Every
-- hit goes through CombatService.damage (a post trains the ability's Path and ignores every
-- effect); its statuses and its pull or knockback follow only when that returned true.
-- Heal-on-hit heals the caster and allies when any hit landed.
local function applyHits(
	player: Player,
	ability: Ability,
	plan: Plan,
	caster: Fighter,
	others: { Fighter }
)
	local connected = false
	for _, hit in plan.hits do
		local id = hit.targetId
		if not inSight(caster, others, id) then
			continue
		end
		if not CombatService.damage(player.UserId, id, hit.damage, { path = ability.path }) then
			continue
		end
		connected = true
		StatusService.applyHit(player.UserId, id, ability)
		-- No ability both pulls and knocks back; each point is for the plan's one target.
		local destination = plan.pullTo or plan.knockbackTo
		if destination ~= nil then
			local humanoid, root = Fighters.body(id)
			if humanoid ~= nil and root ~= nil then
				-- No pull or knockback ever lands a creature inside Tallyport.
				local entry = Fighters.get(id)
				if entry ~= nil and entry.kind == "creature" then
					destination = CreatureBrain.outsideTown(destination)
				end
				Sight.move(humanoid, root, destination)
			end
		end
	end
	local amount = ability.heal
	if connected and ability.healOnHit == true and amount ~= nil then
		for _, ally in alliesOf(player, ability) do
			heal(ally, amount)
		end
	end
end

-- Heal (unless it is a heal-on-hit), cleanse, shield, immune, empower, reduction and reflect
-- on the caster and allies.
local function applySelfEffects(player: Player, ability: Ability)
	local amount = if ability.healOnHit == true then nil else ability.heal
	local cleanse = ability.cleanse == true
	local shield, immune, empower = ability.shield, ability.immune, ability.empower
	local reduction, reflect = ability.reduction, ability.reflect
	local anyStatus = cleanse
		or shield ~= nil
		or immune ~= nil
		or empower ~= nil
		or reduction ~= nil
		or reflect ~= nil
	if amount == nil and not anyStatus then
		return
	end
	for _, ally in alliesOf(player, ability) do
		if amount ~= nil then
			heal(ally, amount)
		end
		if not anyStatus then
			continue
		end
		StatusService.update(ally.UserId, function(status, now)
			local out = status
			if cleanse then
				out = Effects.cleanse(out)
			end
			if shield ~= nil then
				out = Effects.applyShield(out, shield.amount, shield.duration, now)
			end
			if immune ~= nil then
				out = Effects.applyImmune(out, immune, now)
			end
			if empower ~= nil then
				out = Effects.applyEmpower(out, empower.bonus, empower.duration, now)
			end
			if reduction ~= nil then
				out = Effects.applyReduction(out, reduction.factor, reduction.duration, now)
			end
			if reflect ~= nil then
				out = Effects.applyReflect(out, reflect.factor, reflect.duration, now)
			end
			return out
		end)
	end
end

-- ---------------------------------------------------------------------------------------
-- Visuals (server-made, short-lived, in workspace.Effects)
-- ---------------------------------------------------------------------------------------

-- One ray per shot, from the caster to the fighter that shot found, or to full range, cut
-- short where something solid blocks it (as the hit is). The fan and the target use the same
-- rules as the plan (Casting and Targeting.shot).
local function showShots(ability: Ability, caster: Fighter, others: { Fighter }, taunter: number?)
	local lx, lz = caster.look.x, caster.look.z
	local length = math.sqrt(lx * lx + lz * lz)
	if not (length > 0 and length < math.huge) then
		return
	end
	lx, lz = lx / length, lz / length
	local range = ability.range or 0
	local shots = ability.shots or 1
	local spread = ability.spread or 0
	local color = pathColor(ability.path)
	local from = Vector3.new(caster.position.x, caster.position.y, caster.position.z)
	for i = 1, shots do
		local angle = 0
		if shots > 1 then
			angle = -spread / 2 + spread * (i - 1) / (shots - 1)
		end
		-- Positive angles turn clockwise seen from above, as in Targeting.shot.
		local radians = math.rad(angle)
		local sin, cos = math.sin(radians), math.cos(radians)
		local to = from + Vector3.new(lx * cos - lz * sin, 0, lx * sin + lz * cos) * range
		local targetId = Targeting.shot(caster, others, range, angle, taunter)
		if targetId ~= nil then
			for _, other in others do
				if other.id == targetId then
					to = vector(other.position)
					break
				end
			end
		end
		local target = if targetId ~= nil then Fighters.model(targetId) else nil
		Fx.ray(from, Sight.obstruction(from, to, target) or to, color)
	end
end

-- ---------------------------------------------------------------------------------------
-- Casting
-- ---------------------------------------------------------------------------------------

-- The fighters a plan may pick from. A single-target melee or shot ability only sees what the
-- caster has a clear line to, so a target behind a corner never swallows the hit (and an
-- unseen taunter forces nothing). Area abilities keep everyone: applyHits skips unseen hits.
local function candidates(ability: Ability, caster: Fighter, others: { Fighter }): { Fighter }
	if ability.kind == "melee" or ability.kind == "shot" then
		return Sight.filter(vector(caster.position), others)
	end
	return others
end

-- Settles a planned zone on the server's own geometry. The centre never lands past a wall
-- (a level ray from the caster's root towards it stops ZONE_WALL_MARGIN short of the hit),
-- and its height is the ground under it, or World.groundY when there is none.
local function placeZone(zone: Casting.Zone, from: Vector3): Casting.Zone
	local params = Sight.rayParams()
	local x, z = zone.center.x, zone.center.z
	local dx, dz = x - from.X, z - from.Z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance > 0 and distance < math.huge then
		local blocked = workspace:Raycast(from, Vector3.new(dx, 0, dz), params)
		if blocked ~= nil then
			local travel = math.max(0, blocked.Distance - ZONE_WALL_MARGIN)
			x, z = from.X + dx / distance * travel, from.Z + dz / distance * travel
		end
	end
	-- Probe from above the caster's height so a centre on higher ground still finds its floor.
	local y = World.groundY
	local probeTop = from.Y + Combat.STRIKE_MAX_HEIGHT
	local ground = workspace:Raycast(
		Vector3.new(x, probeTop, z),
		Vector3.new(0, -(Sight.GROUND_PROBE + Combat.STRIKE_MAX_HEIGHT), 0),
		params
	)
	if ground ~= nil then
		y = ground.Position.Y
	end
	local placed = table.clone(zone)
	placed.center = { x = x, y = y, z = z }
	return placed
end

-- A later wave (Rending Flurry): re-planned from where the caster is now. Skipped if the caster
-- left, died or respawned since the cast.
local function runWave(player: Player, character: Model?, ability: Ability)
	if player.Parent ~= Players or player.Character ~= character then
		return
	end
	local humanoid, root = living(player)
	if humanoid == nil or root == nil then
		return
	end
	local now = os.clock()
	local others = Fighters.list(player.UserId)
	local taunter = Effects.tauntedBy(StatusService.get(player.UserId), now)
	local caster = fighterOf(player, humanoid, root)
	local plan = Casting.plan(ability, caster, candidates(ability, caster, others), taunter)
	applyHits(player, ability, plan, caster, others)
end

local function handleCast(player: Player, rawSlot: any)
	if player.Parent ~= Players then
		return
	end
	local humanoid, root = living(player)
	if humanoid == nil or root == nil or not allowed(player) then
		return
	end
	local progress = PathService.get(player)
	if progress == nil then
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return
	end
	if progress.calling == "" then
		LedgerService.notify(player, "NO_CALLING")
		return
	end

	-- No yielding call from here to the commit: the cooldown check cannot go stale.
	local now = os.clock()
	local status = StatusService.get(player.UserId)
	local state = castStates[player] or Casting.new()
	local id, code = Casting.canCast(state, progress, rawSlot, now, Effects.isRooted(status, now))
	if id == nil then
		if code ~= "ON_COOLDOWN" then
			LedgerService.notify(player, code)
		end
		return
	end
	local ability = Abilities.byId[id]
	if ability == nil then
		return
	end
	castStates[player] = Casting.commit(state, id, now)
	-- canCast accepted the slot, so it is a whole number from 1 to 4.
	cooldownRemote:FireClient(player, rawSlot :: number, ability.cooldown)

	local character = player.Character
	local others = Fighters.list(player.UserId)
	local taunter = Effects.tauntedBy(status, now)
	local caster = fighterOf(player, humanoid, root)
	local targets = candidates(ability, caster, others)
	local plan = Casting.plan(ability, caster, targets, taunter)

	local moveTo = plan.moveTo
	if moveTo ~= nil then
		local clear = Sight.move(humanoid, root, moveTo)
		if ability.kind == "dash" then
			-- The plan scanned the dash's full length; a wall can stop it short. Only an enemy
			-- inside the stretch actually travelled, plus the gap to what stopped it (the move
			-- halts WALL_MARGIN short of it, and a post's centre is a further stud in), is
			-- passed, scanned from the start point. Line of sight still rules out anything
			-- behind a wall.
			local hits: { Casting.Hit } = {}
			local reach = math.min(ability.distance or 0, clear + Sight.WALL_MARGIN + 1.5)
			local targetId = Targeting.dashHit(caster, others, reach)
			if targetId ~= nil then
				table.insert(hits, { targetId = targetId, damage = ability.damage or 0 })
			end
			plan.hits = hits
		end
	end
	applyHits(player, ability, plan, caster, others)
	for k = 1, plan.waves - 1 do
		task.delay(plan.interval * k, runWave, player, character, ability)
	end
	local zone = plan.zone
	if zone ~= nil then
		StatusService.addZone(player.UserId, placeZone(zone, root.Position), ability.path)
	end
	applySelfEffects(player, ability)

	if ability.kind == "shot" then
		showShots(ability, caster, targets, taunter)
	elseif ability.kind == "burst" then
		local p = caster.position
		local center = Vector3.new(p.x, p.y - Sight.standHeight(humanoid, root) + RING_LIFT, p.z)
		Fx.ring(center, ability.radius or 0, pathColor(ability.path))
	end
end

function AbilityService.start()
	cooldownRemote = LedgerService.makeRemote(Net.AbilityCooldown)
	LedgerService.makeRemote(Net.CastAbility).OnServerEvent:Connect(handleCast)
	Fx.folder()

	Players.PlayerRemoving:Connect(function(player)
		castStates[player] = nil
		buckets[player] = nil
	end)
end

return AbilityService
