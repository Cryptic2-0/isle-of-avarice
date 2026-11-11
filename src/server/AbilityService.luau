--!strict
-- Turns a client's "cast slot N" into the effects of the 18 abilities. The client names only
-- a slot: the ability, targets, damage, movement and timing are all decided here, from the pure
-- Casting plan and the server's own view of the world. Every player hit goes through
-- CombatService.damage, and a hit's statuses, pull or knockback follow only when it landed.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Catalog.Abilities)
local Casting = require(ReplicatedStorage.Shared.Rules.Casting)
local Combat = require(ReplicatedStorage.Shared.Rules.Combat)
local Effects = require(ReplicatedStorage.Shared.Rules.Effects)
local Net = require(ReplicatedStorage.Shared.Net)
local Paths = require(ReplicatedStorage.Shared.Catalog.Paths)
local RateLimiter = require(ReplicatedStorage.Shared.Rules.RateLimiter)
local Targeting = require(ReplicatedStorage.Shared.Rules.Targeting)
local Types = require(ReplicatedStorage.Shared.Types)
local CombatService = require(script.Parent.CombatService)
local LedgerService = require(script.Parent.LedgerService)
local PathService = require(script.Parent.PathService)
local StatusService = require(script.Parent.StatusService)

type Ability = Types.Ability
type Fighter = Combat.Fighter
type Plan = Casting.Plan
type Vec3 = Types.Vec3

local BUCKET_CAPACITY = 10
local BUCKET_REFILL_PER_SECOND = 5
local WALL_MARGIN = 2 -- a move stops this many studs short of anything in its way
local GROUND_PROBE = 50 -- how far below a move's end point to look for ground
local R6_LEG_HEIGHT = 2
local SHOT_WIDTH = 0.3
local SHOT_SECONDS = 0.15
local RING_SECONDS = 0.3
local RING_SEGMENTS = 24
local RING_WIDTH = 0.6
local RING_HEIGHT = 0.2
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

local function effectsFolder(): Folder
	local existing = workspace:FindFirstChild("Effects")
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Effects"
	folder.Parent = workspace
	return folder
end

local function pathColor(path: string): Color3
	local info = Paths.info[path :: Types.PathId]
	if info == nil then
		return DEFAULT_COLOR
	end
	return Color3.fromRGB(info.color.r, info.color.g, info.color.b)
end

-- Height of the root's centre above the feet of a standing character.
local function standHeight(humanoid: Humanoid, root: BasePart): number
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return R6_LEG_HEIGHT + root.Size.Y / 2
end

-- ---------------------------------------------------------------------------------------
-- World rays: movement (dash, pull, knockback) and line of sight
-- ---------------------------------------------------------------------------------------

-- Move and sight rays pass through every player's character and the effects folder, and
-- through anything a character could walk through (non-colliding parts, water).
local function worldRayParams(): RaycastParams
	local exclude: { Instance } = { effectsFolder() }
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character ~= nil then
			table.insert(exclude, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return params
end

-- Where the straight line from `from` to `to` is first blocked, or nil when it is clear.
-- Characters, workspace.Effects and non-colliding parts never block. When the target is a
-- training post, pass its id: the ray ends on that post's own surface, which is not a block.
local function obstruction(from: Vector3, to: Vector3, postId: number?): Vector3?
	local delta = to - from
	-- Written so a NaN or infinite line counts as blocked.
	if not (delta.Magnitude < math.huge) then
		return from
	end
	local result = workspace:Raycast(from, delta, worldRayParams())
	if result == nil then
		return nil
	end
	if postId ~= nil and result.Instance:GetAttribute("PostId") == postId then
		return nil
	end
	return result.Position
end

-- Moves a character towards `target` using only the server's own geometry. `target` always
-- comes from a server plan, never from a client. A level ray from the root towards the
-- target's x and z stops WALL_MARGIN short of anything in the way; a ray down from there
-- stands the character on the ground, or keeps its current height if there is none. The
-- facing is kept and the velocity zeroed. Returns the level distance actually travelled
-- (0 when nothing moved).
local function moveCharacter(humanoid: Humanoid, root: BasePart, target: Vec3): number
	local from = root.Position
	local dx = target.x - from.X
	local dz = target.z - from.Z
	local distance = math.sqrt(dx * dx + dz * dz)
	-- Written so NaN or infinite targets move nobody.
	if not (distance > 0 and distance < math.huge) then
		return 0
	end
	local direction = Vector3.new(dx / distance, 0, dz / distance)
	local params = worldRayParams()
	local travel = distance
	local blocked = workspace:Raycast(from, direction * distance, params)
	if blocked ~= nil then
		travel = math.max(0, blocked.Distance - WALL_MARGIN)
	end
	local stop = from + direction * travel
	local y = from.Y
	local ground = workspace:Raycast(stop, Vector3.new(0, -GROUND_PROBE, 0), params)
	if ground ~= nil then
		y = ground.Position.Y + standHeight(humanoid, root)
	end
	root.CFrame = CFrame.new(stop.X, y, stop.Z) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero
	return travel
end

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

-- The hit's statuses on a victim the damage reached. Only called after damage() returned true.
local function applyHitStatuses(player: Player, ability: Ability, victim: Player)
	local burn, rootFor, slow, taunt = ability.burn, ability.root, ability.slow, ability.taunt
	if burn == nil and rootFor == nil and slow == nil and taunt == nil then
		return
	end
	local byId = player.UserId
	StatusService.update(victim, function(status, now)
		local out = status
		if burn ~= nil then
			out = Effects.applyBurn(out, burn.dps, burn.duration, byId, now)
		end
		if rootFor ~= nil then
			out = Effects.applyRoot(out, rootFor, now)
		end
		if slow ~= nil then
			out = Effects.applySlow(out, slow.factor, slow.duration, now)
		end
		if taunt ~= nil then
			out = Effects.applyTaunt(out, byId, taunt, now)
		end
		return out
	end)
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
			local postId = if CombatService.isPost(targetId) then targetId else nil
			return obstruction(vector(caster.position), vector(other.position), postId) == nil
		end
	end
	return false
end

-- Applies a plan's hits. A hit the caster has no line of sight to is skipped entirely. A post
-- trains the ability's Path (posts ignore every effect); a player takes the hit through
-- CombatService.damage, and its statuses and its pull or knockback follow only when that
-- returned true. Heal-on-hit heals the caster and allies when any player hit landed or a post
-- was hit.
local function applyHits(
	player: Player,
	ability: Ability,
	plan: Plan,
	caster: Fighter,
	others: { Fighter },
	byId: { [number]: Player }
)
	local connected = false
	for _, hit in plan.hits do
		if not inSight(caster, others, hit.targetId) then
			continue
		end
		if CombatService.isPost(hit.targetId) then
			CombatService.hitPost(player, hit.targetId, ability.path)
			connected = true
			continue
		end
		local victim = byId[hit.targetId]
		if victim == nil or not CombatService.damage(player, victim, hit.damage) then
			continue
		end
		connected = true
		applyHitStatuses(player, ability, victim)
		-- No ability both pulls and knocks back; each point is for the plan's one target.
		local destination = plan.pullTo or plan.knockbackTo
		if destination ~= nil then
			local humanoid, root = living(victim)
			if humanoid ~= nil and root ~= nil then
				moveCharacter(humanoid, root, destination)
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
		StatusService.update(ally, function(status, now)
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

local function effectPart(name: string, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	return part
end

local function showRay(from: Vector3, to: Vector3, color: Color3)
	local length = (to - from).Magnitude
	if not (length > 0 and length < math.huge) then
		return
	end
	local part = effectPart("Shot", color)
	part.Size = Vector3.new(SHOT_WIDTH, SHOT_WIDTH, length)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	part.Parent = effectsFolder()
	Debris:AddItem(part, SHOT_SECONDS)
end

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
		local postId = if targetId ~= nil and CombatService.isPost(targetId) then targetId else nil
		showRay(from, obstruction(from, to, postId) or to, color)
	end
end

-- A flat ring of the burst's radius around the caster's feet.
local function showRing(center: Vector3, radius: number, color: Color3)
	if not (radius > 0 and radius < math.huge) then
		return
	end
	local ring = Instance.new("Model")
	ring.Name = "Ring"
	local segment = 2 * radius * math.sin(math.pi / RING_SEGMENTS) + RING_WIDTH
	for i = 1, RING_SEGMENTS do
		local part = effectPart("Segment", color)
		-- Local X points outwards from the centre, local Z along the ring.
		part.Size = Vector3.new(RING_WIDTH, RING_HEIGHT, segment)
		part.CFrame = CFrame.new(center)
			* CFrame.Angles(0, (i - 1) / RING_SEGMENTS * 2 * math.pi, 0)
			* CFrame.new(radius, 0, 0)
		part.Parent = ring
	end
	ring.Parent = effectsFolder()
	Debris:AddItem(ring, RING_SECONDS)
end

-- ---------------------------------------------------------------------------------------
-- Casting
-- ---------------------------------------------------------------------------------------

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
	local others, byId = CombatService.fighters(player)
	local taunter = Effects.tauntedBy(StatusService.get(player), now)
	local caster = fighterOf(player, humanoid, root)
	local plan = Casting.plan(ability, caster, others, taunter)
	applyHits(player, ability, plan, caster, others, byId)
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
	local status = StatusService.get(player)
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
	local others, byId = CombatService.fighters(player)
	local taunter = Effects.tauntedBy(status, now)
	local caster = fighterOf(player, humanoid, root)
	local plan = Casting.plan(ability, caster, others, taunter)

	local moveTo = plan.moveTo
	if moveTo ~= nil then
		local clear = moveCharacter(humanoid, root, moveTo)
		if ability.kind == "dash" then
			-- The plan scanned the dash's full length; a wall can stop it short. Only an enemy
			-- inside the stretch actually travelled, plus the gap to what stopped it (the move
			-- halts WALL_MARGIN short of it, and a post's centre is a further stud in), is
			-- passed, scanned from the start point. Line of sight still rules out anything
			-- behind a wall.
			local hits: { Casting.Hit } = {}
			local reach = math.min(ability.distance or 0, clear + WALL_MARGIN + 1.5)
			local targetId = Targeting.dashHit(caster, others, reach)
			if targetId ~= nil then
				table.insert(hits, { targetId = targetId, damage = ability.damage or 0 })
			end
			plan.hits = hits
		end
	end
	applyHits(player, ability, plan, caster, others, byId)
	for k = 1, plan.waves - 1 do
		task.delay(plan.interval * k, runWave, player, character, ability)
	end
	local zone = plan.zone
	if zone ~= nil then
		StatusService.addZone(player, zone, ability.path)
	end
	applySelfEffects(player, ability)

	if ability.kind == "shot" then
		showShots(ability, caster, others, taunter)
	elseif ability.kind == "burst" then
		local p = caster.position
		local center = Vector3.new(p.x, p.y - standHeight(humanoid, root) + RING_LIFT, p.z)
		showRing(center, ability.radius or 0, pathColor(ability.path))
	end
end

function AbilityService.start()
	cooldownRemote = LedgerService.makeRemote(Net.AbilityCooldown)
	LedgerService.makeRemote(Net.CastAbility).OnServerEvent:Connect(handleCast)
	effectsFolder()

	Players.PlayerRemoving:Connect(function(player)
		castStates[player] = nil
		buckets[player] = nil
	end)
end

return AbilityService
