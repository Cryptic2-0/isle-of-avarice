--!strict
-- Owns every player's effect status (slow, root, burn, shield, ...) and the ground zones.
-- Never requires CombatService: Main passes its damage and hitPost functions into start(),
-- so every burn and zone tick goes through the one damage pipeline.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Casting = require(ReplicatedStorage.Shared.Rules.Casting)
local Effects = require(ReplicatedStorage.Shared.Rules.Effects)
local Paths = require(ReplicatedStorage.Shared.Catalog.Paths)
local Types = require(ReplicatedStorage.Shared.Types)
local World = require(ReplicatedStorage.Shared.Catalog.World)

type Status = Effects.Status
-- CombatService.damage: true when the hit landed.
type DamageFn = (
	attacker: Player,
	victim: Player,
	amount: number,
	opts: { reflected: boolean?, tick: boolean? }?
) -> boolean
type HitPostFn = (attacker: Player, postId: number, path: string) -> ()

type ZoneEntry = {
	owner: Player,
	x: number,
	z: number,
	radius: number,
	dps: number,
	slow: number?,
	path: string,
	expiresAt: number,
	part: BasePart?,
}

local BASE_WALK_SPEED = 16
local TICK_SECONDS = 1
local ZONE_SLOW_SECONDS = 1.2
local ZONE_THICKNESS = 0.3
local ZONE_TRANSPARENCY = 0.6
local ZONE_DEFAULT_COLOR = Color3.fromRGB(200, 200, 200)

local StatusService = {}

-- Time from os.clock() everywhere.
local statuses: { [Player]: Status } = {}
local zones: { ZoneEntry } = {}
-- The Humanoid whose jump we zeroed for a root, so it can be restored afterwards.
local jumpBlocked: { [Player]: Humanoid } = {}
local damageFn: DamageFn? = nil
local hitPostFn: HitPostFn? = nil
local nextTick = 0

-- Read-only defaults for a player with no entry. Never written to.
local FRESH: Status = Effects.new()

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
	part.CFrame = CFrame.new(entry.x, World.groundY + 0.25, entry.z)
		* CFrame.Angles(0, 0, math.pi / 2)
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
		if not (now < entry.expiresAt) or entry.owner.Parent ~= Players then
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

local function tickBurns(now: number, damage: DamageFn)
	-- Snapshot first: damage writes statuses while we would otherwise be iterating them.
	local burns: { { victim: Player, dps: number, burnBy: number } } = {}
	for victim, status in statuses do
		local dps, burnBy = Effects.burnTick(status, now)
		if dps > 0 and burnBy ~= 0 then
			table.insert(burns, { victim = victim, dps = dps, burnBy = burnBy })
		end
	end
	for _, burn in burns do
		local found = Players:GetPlayerByUserId(burn.burnBy)
		if found == nil then
			continue
		end
		local burner: Player = found
		guarded("burn tick", function()
			damage(burner, burn.victim, burn.dps, { tick = true })
		end)
	end
end

local function tickZone(entry: ZoneEntry, damage: DamageFn, hitPost: HitPostFn?)
	local owner = entry.owner
	if owner.Parent ~= Players then
		return
	end
	for _, victim in Players:GetPlayers() do
		if victim == owner then
			continue
		end
		local _, root = living(victim)
		if root == nil then
			continue
		end
		local p = root.Position
		if not (horizontalDistance(p.X, p.Z, entry.x, entry.z) <= entry.radius) then
			continue
		end
		-- The slow is only refreshed on a victim the damage actually reached.
		local landed = damage(owner, victim, entry.dps, { tick = true })
		local slow = entry.slow
		if landed and slow ~= nil then
			local factor: number = slow
			StatusService.update(victim, function(status, at)
				return Effects.applySlow(status, factor, ZONE_SLOW_SECONDS, at)
			end)
		end
	end
	if hitPost ~= nil then
		for i, post in World.trainingPosts do
			if horizontalDistance(post.x, post.z, entry.x, entry.z) <= entry.radius then
				hitPost(owner, World.POST_ID_BASE - i, entry.path)
			end
		end
	end
end

local function tick(now: number)
	local configured = damageFn
	if configured == nil then
		return
	end
	local damage: DamageFn = configured
	local hitPost = hitPostFn
	tickBurns(now, damage)
	-- A copy: a zone's owner leaving mid-tick must not shift the list under us.
	for _, entry in table.clone(zones) do
		if now < entry.expiresAt then
			guarded("zone tick", function()
				tickZone(entry, damage, hitPost)
			end)
		end
	end
end

-- Walk speed follows slow and root; jumping is off while rooted.
local function applyMovement(now: number)
	for _, player in Players:GetPlayers() do
		local humanoid = living(player)
		if humanoid == nil then
			continue
		end
		local status = statuses[player] or FRESH
		local speed = BASE_WALK_SPEED * Effects.speedFactor(status, now)
		if humanoid.WalkSpeed ~= speed then
			humanoid.WalkSpeed = speed
		end
		local blocked = jumpBlocked[player]
		if Effects.isRooted(status, now) then
			if blocked ~= humanoid then
				humanoid.JumpPower = 0
				humanoid.JumpHeight = 0
				jumpBlocked[player] = humanoid
			end
		elseif blocked ~= nil then
			if blocked == humanoid then
				humanoid.JumpPower = StarterPlayer.CharacterJumpPower
				humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
			end
			jumpBlocked[player] = nil
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

local function watchPlayer(player: Player)
	statuses[player] = Effects.new()
	player.CharacterAdded:Connect(function()
		statuses[player] = Effects.new()
		jumpBlocked[player] = nil
	end)
end

local function dropPlayer(player: Player)
	statuses[player] = nil
	jumpBlocked[player] = nil
	for i = #zones, 1, -1 do
		if zones[i].owner == player then
			removeZone(i)
		end
	end
end

-- The player's status; a fresh one when they have none. Treat it as read-only.
function StatusService.get(player: Player): Status
	return statuses[player] or Effects.new()
end

-- Replaces the player's status with fn(status, now). No yielding inside fn. A player who
-- has left (no entry) is not given a new one.
function StatusService.update(player: Player, fn: (Status, number) -> Status)
	local current = statuses[player]
	local nextStatus = fn(current or Effects.new(), os.clock())
	if current ~= nil then
		statuses[player] = nextStatus
	end
end

-- A ground zone owned by `owner`: once a second it damages every other living player
-- inside and pays `path` XP for every training post inside, until it expires.
function StatusService.addZone(owner: Player, zone: Casting.Zone, path: string)
	if owner.Parent ~= Players then
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
		owner = owner,
		x = zone.center.x,
		z = zone.center.z,
		radius = radius,
		dps = dps,
		slow = zone.slow,
		path = path,
		expiresAt = os.clock() + duration,
		part = nil,
	}
	entry.part = makeZonePart(entry)
	table.insert(zones, entry)
end

function StatusService.start(damage: DamageFn, hitPost: HitPostFn)
	damageFn = damage
	hitPostFn = hitPost
	effectsFolder()

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(dropPlayer)

	nextTick = os.clock() + TICK_SECONDS
	RunService.Heartbeat:Connect(onHeartbeat)
end

return StatusService
