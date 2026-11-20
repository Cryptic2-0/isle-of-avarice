--!strict
-- Owns every fighter's effect status (slow, root, burn, shield, ...), keyed by fighter id
-- (see Fighters), and the ground zones. Never requires CombatService: Main passes its damage
-- function into start(), so every burn and zone tick goes through the one damage pipeline.
-- The only writer of WalkSpeed: baseSpeed × Effects.speedFactor, for every fighter with a body.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Casting = require(ReplicatedStorage.Shared.Rules.Casting)
local Combat = require(ReplicatedStorage.Shared.Rules.Combat)
local Effects = require(ReplicatedStorage.Shared.Rules.Effects)
local Paths = require(ReplicatedStorage.Shared.Catalog.Paths)
local Types = require(ReplicatedStorage.Shared.Types)
local Fighters = require(script.Parent.Fighters)

type Status = Effects.Status
type DamageOpts = { reflected: boolean?, tick: boolean?, passive: boolean?, path: string? }
-- CombatService.damage: true when the hit landed.
type DamageFn = (attackerId: number, targetId: number, amount: number, opts: DamageOpts?) -> boolean

type ZoneEntry = {
	owner: number,
	x: number,
	y: number,
	-- Fighters inside when the zone was placed; others who walk in later are passive targets.
	inside: { [number]: boolean },
	z: number,
	radius: number,
	dps: number,
	slow: number?,
	path: string,
	expiresAt: number,
	part: BasePart?,
}

local TICK_SECONDS = 1
local ZONE_SLOW_SECONDS = 1.2
local ZONE_THICKNESS = 0.3
local ZONE_TRANSPARENCY = 0.6
local ZONE_DEFAULT_COLOR = Color3.fromRGB(200, 200, 200)

local StatusService = {}

-- Time from os.clock() everywhere. All keyed by fighter id.
local statuses: { [number]: Status } = {}
-- The Path of the ability that set each fighter's current burn, for the burn's ticks.
local burnPaths: { [number]: string } = {}
local zones: { ZoneEntry } = {}
-- The Humanoid whose jump we zeroed for a root, so it can be restored afterwards (players).
local jumpBlocked: { [number]: Humanoid } = {}
local damageFn: DamageFn? = nil
local nextTick = 0

-- Read-only defaults for a fighter with no entry. Never written to.
local FRESH: Status = Effects.new()

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
		return ZONE_DEFAULT_COLOR
	end
	return Color3.fromRGB(info.color.r, info.color.g, info.color.b)
end

-- A translucent neon disc of the zone's radius lying on the ground.
local function makeZonePart(entry: ZoneEntry): BasePart
	local part = Instance.new("Part")
	part.Name = "Zone"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = pathColor(entry.path)
	part.Transparency = ZONE_TRANSPARENCY
	-- A cylinder's axis is its X axis: stand it on end, then lay it flat.
	part.Size = Vector3.new(ZONE_THICKNESS, entry.radius * 2, entry.radius * 2)
	part.CFrame = CFrame.new(entry.x, entry.y + 0.25, entry.z) * CFrame.Angles(0, 0, math.pi / 2)
	part.Parent = effectsFolder()
	return part
end

local function removeZone(index: number)
	local entry = table.remove(zones, index)
	if entry ~= nil and entry.part ~= nil then
		entry.part:Destroy()
	end
end

local function removeExpiredZones(now: number)
	for i = #zones, 1, -1 do
		local entry = zones[i]
		-- Written so a NaN time removes the zone rather than keeping it forever.
		if not (now < entry.expiresAt) or Fighters.get(entry.owner) == nil then
			removeZone(i)
		end
	end
end

local function horizontalDistance(ax: number, az: number, bx: number, bz: number): number
	local dx = ax - bx
	local dz = az - bz
	return math.sqrt(dx * dx + dz * dz)
end

-- Runs one tick step; a failure is reported and does not stop the other steps.
local function guarded(name: string, step: () -> ())
	local ok, err = pcall(step)
	if not ok then
		warn(`[IsleOfAvarice] StatusService {name} failed: {err}`)
	end
end

-- True when a fighter at `p` is inside the zone: within its radius on the ground plane and
-- within the height tolerance every other targeting rule uses.
local function zoneContains(entry: ZoneEntry, p: Types.Vec3): boolean
	return horizontalDistance(p.x, p.z, entry.x, entry.z) <= entry.radius
		and math.abs(p.y - entry.y) <= Combat.STRIKE_MAX_HEIGHT
end

local function tickBurns(now: number, damage: DamageFn)
	-- Snapshot first: damage writes statuses while we would otherwise be iterating them.
	local burns: { { victim: number, dps: number, burnBy: number, path: string } } = {}
	for id, status in statuses do
		local dps, burnBy = Effects.burnTick(status, now)
		if dps > 0 and burnBy ~= 0 then
			table.insert(
				burns,
				{ victim = id, dps = dps, burnBy = burnBy, path = burnPaths[id] or "" }
			)
		end
	end
	for _, burn in burns do
		-- A burner who has gone (left, or a creature despawned) burns no more.
		if Fighters.get(burn.burnBy) == nil then
			continue
		end
		guarded("burn tick", function()
			damage(burn.burnBy, burn.victim, burn.dps, { tick = true, path = burn.path })
		end)
	end
end

local function tickZone(entry: ZoneEntry, damage: DamageFn)
	local owner = entry.owner
	if Fighters.get(owner) == nil then
		return
	end
	for _, target in Fighters.list(owner) do
		if not zoneContains(entry, target.position) then
			continue
		end
		-- Someone who walked in after placement is hurt and slowed, but the owner is not
		-- marked, loses no respawn shield and starts no fight by it.
		local passive = not entry.inside[target.id]
		-- Posts pay the zone's Path; players (and creatures) take the damage.
		local landed = damage(
			owner,
			target.id,
			entry.dps,
			{ tick = true, passive = passive, path = entry.path }
		)
		-- The slow is only refreshed on a target the damage actually reached; posts ignore it.
		local slow = entry.slow
		local targetEntry = Fighters.get(target.id)
		if landed and slow ~= nil and targetEntry ~= nil and targetEntry.kind ~= "post" then
			local factor: number = slow
			StatusService.update(target.id, function(status, at)
				return Effects.applySlow(status, factor, ZONE_SLOW_SECONDS, at)
			end)
		end
	end
end

local function tick(now: number)
	local configured = damageFn
	if configured == nil then
		return
	end
	local damage: DamageFn = configured
	tickBurns(now, damage)
	-- A copy: a zone's owner leaving mid-tick must not shift the list under us.
	for _, entry in table.clone(zones) do
		if now < entry.expiresAt then
			guarded("zone tick", function()
				tickZone(entry, damage)
			end)
		end
	end
end

-- Walk speed follows slow and root for every fighter with a living body; jumping is off
-- while a player is rooted.
local function applyMovement(now: number)
	for _, entry in Fighters.all() do
		local id = entry.id
		local humanoid = Fighters.body(id)
		if humanoid == nil then
			continue
		end
		local status = statuses[id] or FRESH
		local speed = entry.baseSpeed * Effects.speedFactor(status, now)
		if humanoid.WalkSpeed ~= speed then
			humanoid.WalkSpeed = speed
		end
		if entry.kind ~= "player" then
			continue
		end
		local blocked = jumpBlocked[id]
		if Effects.isRooted(status, now) then
			if blocked ~= humanoid then
				humanoid.JumpPower = 0
				humanoid.JumpHeight = 0
				jumpBlocked[id] = humanoid
			end
		elseif blocked ~= nil then
			if blocked == humanoid then
				humanoid.JumpPower = StarterPlayer.CharacterJumpPower
				humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
			end
			jumpBlocked[id] = nil
		end
	end
end

local function onHeartbeat()
	local now = os.clock()
	applyMovement(now)
	removeExpiredZones(now)
	if now >= nextTick then
		nextTick = now + TICK_SECONDS
		tick(now)
	end
end

-- The fighter's status; a fresh one when it has none. Treat it as read-only.
function StatusService.get(id: number): Status
	return statuses[id] or Effects.new()
end

-- Replaces the fighter's status with fn(status, now). No yielding inside fn. A fighter with
-- no entry (a post, or a player who has left) is not given one: fn sees a fresh status and
-- its result is dropped.
function StatusService.update(id: number, fn: (Status, number) -> Status)
	local current = statuses[id]
	local nextStatus = fn(current or Effects.new(), os.clock())
	if current ~= nil then
		statuses[id] = nextStatus
	end
end

-- A fresh status: players on join and respawn, creatures on spawn.
function StatusService.reset(id: number)
	statuses[id] = Effects.new()
	burnPaths[id] = nil
	jumpBlocked[id] = nil
end

-- Forgets the fighter's status and burn Path, and removes the zones it owns.
function StatusService.drop(id: number)
	statuses[id] = nil
	burnPaths[id] = nil
	jumpBlocked[id] = nil
	for i = #zones, 1, -1 do
		if zones[i].owner == id then
			removeZone(i)
		end
	end
end

-- A landed ability hit's statuses on the target (Effects.applyHit). The burn remembers the
-- ability's Path for its ticks. A target with no status (a post) is left alone.
function StatusService.applyHit(attackerId: number, targetId: number, ability: Types.Ability)
	if statuses[targetId] == nil then
		return
	end
	StatusService.update(targetId, function(status, now)
		return Effects.applyHit(status, ability, attackerId, now)
	end)
	if ability.burn ~= nil then
		burnPaths[targetId] = ability.path
	end
end

-- A ground zone owned by `ownerId`: once a second it damages every other fighter inside
-- (posts pay `path` XP), until it expires or its owner is gone.
function StatusService.addZone(ownerId: number, zone: Casting.Zone, path: string)
	if Fighters.get(ownerId) == nil then
		return
	end
	local radius, duration, dps = zone.radius, zone.duration, zone.dps
	if
		not (radius > 0 and radius < math.huge)
		or not (duration > 0 and duration < math.huge)
		or not (dps >= 0 and dps < math.huge)
		or not (math.abs(zone.center.x) < math.huge and math.abs(zone.center.z) < math.huge)
	then
		return
	end
	local entry: ZoneEntry = {
		owner = ownerId,
		x = zone.center.x,
		y = zone.center.y,
		z = zone.center.z,
		inside = {},
		radius = radius,
		dps = dps,
		slow = zone.slow,
		path = path,
		expiresAt = os.clock() + duration,
		part = nil,
	}
	if not (math.abs(zone.center.y) < math.huge) then
		return
	end
	-- Every fighter standing in it counts, allies included: an ally removed from the party
	-- later must not turn into a passive target.
	for _, other in Fighters.all() do
		if other.id == ownerId then
			continue
		end
		local fighter = Fighters.fighter(other.id)
		if fighter ~= nil and zoneContains(entry, fighter.position) then
			entry.inside[other.id] = true
		end
	end
	entry.part = makeZonePart(entry)
	table.insert(zones, entry)
end

function StatusService.start(damage: DamageFn)
	damageFn = damage
	effectsFolder()

	local function watchPlayer(player: Player)
		StatusService.reset(player.UserId)
		player.CharacterAdded:Connect(function()
			StatusService.reset(player.UserId)
		end)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- Leave a rejoin under the same UserId alone.
		local entry = Fighters.get(player.UserId)
		if entry == nil or entry.player == player then
			StatusService.drop(player.UserId)
		end
	end)

	nextTick = os.clock() + TICK_SECONDS
	RunService.Heartbeat:Connect(onHeartbeat)
end

return StatusService
