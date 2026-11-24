--!strict
-- The island's creatures: builds them at their dens, runs each one's brain ten times a second
-- (CreatureBrain decides, this applies), carries out their attacks through the one damage
-- pipeline, and pays everyone who helped when one is defeated (Rewards decides who and what).
-- Also spawns the Drowned Tallyman for a duel: a creature only its owner can fight.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combat = require(ReplicatedStorage.Shared.Rules.Combat)
local CreatureBrain = require(ReplicatedStorage.Shared.Rules.CreatureBrain)
local Creatures = require(ReplicatedStorage.Shared.Catalog.Creatures)
local Effects = require(ReplicatedStorage.Shared.Rules.Effects)
local Geography = require(ReplicatedStorage.Shared.Rules.Geography)
local Ledger = require(ReplicatedStorage.Shared.Rules.Ledger)
local Protection = require(ReplicatedStorage.Shared.Rules.Protection)
local Rewards = require(ReplicatedStorage.Shared.Rules.Rewards)
local Targeting = require(ReplicatedStorage.Shared.Rules.Targeting)
local Types = require(ReplicatedStorage.Shared.Types)
local World = require(ReplicatedStorage.Shared.Catalog.World)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)
local Fx = require(script.Parent.Fx)
local LedgerService = require(script.Parent.LedgerService)
local Payout = require(script.Parent.Payout)
local ProtectionService = require(script.Parent.ProtectionService)
local Sight = require(script.Parent.Sight)
local SourceService = require(script.Parent.SourceService)
local StatusService = require(script.Parent.StatusService)

type CreatureKind = Types.CreatureKind
type Vec3 = Types.Vec3

export type Info = {
	kind: string,
	alive: boolean,
	mode: string,
	targetId: number,
	position: Vector3?,
	owner: Player?,
}

type Creature = {
	id: number,
	kind: CreatureKind,
	den: Vec3,
	owner: Player?,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	brain: CreatureBrain.Brain,
	tally: Rewards.Tally,
	-- The last player to hit it since the previous brain tick.
	provoker: number?,
	-- True once it is standing still because it is not in the active set.
	parked: boolean,
	gone: boolean,
}

-- One piece of a creature's look. `at` is the piece's centre: x to its right, y above the
-- ground, z behind it (a creature faces -z).
type Piece = {
	name: string,
	size: Vector3,
	at: Vector3,
	color: Color3?, -- the kind's own colour when nil
	ball: boolean?,
}
-- `root` is the invisible body that walks and collides; `centre` its height above the ground.
type Look = { root: Vector3, centre: number, pieces: { Piece } }

local FOLDER_NAME = "Creatures"
local TAG = "Creature"
local MEMBER_SPACING = 4
local MELEE_SLACK = 1 -- a bite still lands if the target stepped this far past the reach
local LUNGE_SLACK = 1.5
local TIP_SECONDS = 1.5
local BAR_DISTANCE = 80
local SHOT_COLOR = Color3.fromRGB(150, 200, 90)
local SLAM_COLOR = Color3.fromRGB(120, 170, 200)
local PALE = Color3.fromRGB(215, 220, 205)
local DARK = Color3.fromRGB(35, 40, 45)
local GOLD = Color3.fromRGB(235, 190, 60)

local LOOKS: { [string]: Look } = {
	-- A low, long body with a fin.
	brinehound = {
		root = Vector3.new(2, 2, 4),
		centre = 1.6,
		pieces = {
			{ name = "Body", size = Vector3.new(2, 1.6, 4.4), at = Vector3.new(0, 1.6, 0) },
			{ name = "Head", size = Vector3.new(1.4, 1.3, 1.5), at = Vector3.new(0, 2, -2.6) },
			{
				name = "Fin",
				size = Vector3.new(0.3, 1.3, 1.6),
				at = Vector3.new(0, 3, 0.4),
				color = DARK,
			},
		},
	},
	-- A wide shell on a flat body.
	shellback = {
		root = Vector3.new(5, 2.5, 5),
		centre = 1.75,
		pieces = {
			{
				name = "Body",
				size = Vector3.new(5, 1, 5.5),
				at = Vector3.new(0, 1, 0),
				color = DARK,
			},
			{ name = "Shell", size = Vector3.new(5.4, 1.8, 5.4), at = Vector3.new(0, 2.4, 0) },
			{ name = "Crown", size = Vector3.new(3.4, 1, 3.4), at = Vector3.new(0, 3.6, 0) },
			{
				name = "Head",
				size = Vector3.new(1.2, 1, 1.2),
				at = Vector3.new(0, 1.2, -3.2),
				color = DARK,
			},
		},
	},
	-- A thin stalk with a big round head.
	bogspitter = {
		root = Vector3.new(2, 4, 2),
		centre = 2,
		pieces = {
			{ name = "Stalk", size = Vector3.new(0.8, 3, 0.8), at = Vector3.new(0, 1.5, 0) },
			{
				name = "Head",
				size = Vector3.new(2.6, 2.6, 2.6),
				at = Vector3.new(0, 3.6, 0),
				ball = true,
			},
			{
				name = "Mouth",
				size = Vector3.new(0.8, 0.8, 0.5),
				at = Vector3.new(0, 3.6, -1.3),
				color = DARK,
			},
		},
	},
	-- A huge barnacled block with two arms.
	brine_colossus = {
		root = Vector3.new(7, 5, 6),
		centre = 2.5,
		pieces = {
			{ name = "Body", size = Vector3.new(8, 12, 6), at = Vector3.new(0, 6, 0) },
			{ name = "Head", size = Vector3.new(4, 2.5, 4), at = Vector3.new(0, 13.2, 0) },
			{ name = "LeftArm", size = Vector3.new(2.5, 8, 2.5), at = Vector3.new(-5.3, 7, 0) },
			{ name = "RightArm", size = Vector3.new(2.5, 8, 2.5), at = Vector3.new(5.3, 7, 0) },
			{
				name = "Barnacle1",
				size = Vector3.new(1.4, 1.4, 0.6),
				at = Vector3.new(-2, 9, -3.2),
				color = PALE,
			},
			{
				name = "Barnacle2",
				size = Vector3.new(1, 1, 0.6),
				at = Vector3.new(2.2, 5, -3.2),
				color = PALE,
			},
			{
				name = "Barnacle3",
				size = Vector3.new(1.2, 1.2, 0.6),
				at = Vector3.new(0.5, 2.5, -3.2),
				color = PALE,
			},
		},
	},
	-- A man-sized coat, a pale head and a gold book.
	drowned_tallyman = {
		root = Vector3.new(2, 2, 1),
		centre = 3,
		pieces = {
			{ name = "Coat", size = Vector3.new(2.2, 4.2, 1.4), at = Vector3.new(0, 2.4, 0) },
			{
				name = "Head",
				size = Vector3.new(1.4, 1.4, 1.4),
				at = Vector3.new(0, 5.3, 0),
				color = PALE,
			},
			{
				name = "Book",
				size = Vector3.new(1, 1.3, 0.3),
				at = Vector3.new(1.3, 2.8, -0.6),
				color = GOLD,
			},
		},
	},
	-- A tall gilded figure with a sash and a gavel.
	gilded_bailiff = {
		root = Vector3.new(6, 6, 5),
		centre = 3,
		pieces = {
			{ name = "Body", size = Vector3.new(6, 9, 4), at = Vector3.new(0, 6.5, 0) },
			{ name = "Head", size = Vector3.new(3, 3, 3), at = Vector3.new(0, 12.5, 0) },
			{
				name = "Sash",
				size = Vector3.new(6.2, 1.2, 4.2),
				at = Vector3.new(0, 8, 0),
				color = PALE,
			},
			{ name = "Arm", size = Vector3.new(1.6, 6, 1.6), at = Vector3.new(-4, 7, 0) },
			{
				name = "GavelHandle",
				size = Vector3.new(0.8, 5, 0.8),
				at = Vector3.new(4, 6, -1.5),
				color = DARK,
			},
			{
				name = "GavelHead",
				size = Vector3.new(3, 2, 2),
				at = Vector3.new(4, 9, -1.5),
				color = DARK,
			},
		},
	},
}

local CreatureService = {}

local creatures: { [number]: Creature } = {}
-- Counts spawns and forced respawns per den creature, so a stale respawn timer does nothing.
local generations: { [number]: number } = {}
-- nil: every creature thinks. A set: only those den creatures (champions always think).
local active: { [number]: boolean }? = nil
local championCount = 0
local accumulated = 0
local defeatCallbacks: { (kind: string, id: number, contributors: { Player }, owner: Player?) -> () } =
	{}

local rng: () -> number = function()
	return math.random()
end

local function folder(): Folder
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = FOLDER_NAME
	made.Parent = workspace
	return made
end

local function vec(v: Vector3): Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- ---------------------------------------------------------------------------------------
-- Building a creature
-- ---------------------------------------------------------------------------------------

local function addBar(root: BasePart, humanoid: Humanoid, kind: CreatureKind, look: Look)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bar"
	gui.Size = UDim2.fromOffset(120, 34)
	gui.StudsOffset = Vector3.new(0, kind.height - look.centre + 2, 0)
	gui.MaxDistance = BAR_DISTANCE
	gui.AlwaysOnTop = true

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.Size = UDim2.fromScale(1, 0.6)
	name.BackgroundTransparency = 1
	name.Text = kind.name
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.5
	name.TextScaled = true
	name.Font = Enum.Font.GothamBold
	name.Parent = gui

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Position = UDim2.fromScale(0, 0.7)
	back.Size = UDim2.fromScale(1, 0.25)
	back.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back

	humanoid.HealthChanged:Connect(function(health)
		local share = if humanoid.MaxHealth > 0 then health / humanoid.MaxHealth else 0
		fill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
	end)
	gui.Parent = root
end

-- The model, standing at `position` on the ground. Not yet parented.
local function buildModel(
	id: number,
	kind: CreatureKind,
	position: Vec3,
	owner: Player?
): (Model, Humanoid, BasePart)
	local look = LOOKS[kind.id] or LOOKS.brinehound
	local model = Instance.new("Model")
	model.Name = kind.name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = look.root
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = false
	root.CFrame = CFrame.new(position.x, World.groundY + look.centre, position.z)
	root.Parent = model
	model.PrimaryPart = root

	local color = Color3.fromRGB(kind.color.r, kind.color.g, kind.color.b)
	for _, piece in look.pieces do
		local part = Instance.new("Part")
		part.Name = piece.name
		part.Size = piece.size
		if piece.ball == true then
			part.Shape = Enum.PartType.Ball
		end
		part.Color = piece.color or color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = root.CFrame * CFrame.new(piece.at.X, piece.at.Y - look.centre, piece.at.Z)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = look.centre - look.root.Y / 2
	humanoid.MaxHealth = kind.health
	humanoid.Health = kind.health
	humanoid.WalkSpeed = kind.speed
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- A one-part body must never tip over, climb or swim.
	for _, state in
		{
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Swimming,
			Enum.HumanoidStateType.Jumping,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end
	humanoid.Parent = model

	model:SetAttribute("CreatureId", id)
	model:SetAttribute("Kind", kind.id)
	model:SetAttribute("OwnerUserId", if owner ~= nil then owner.UserId else 0)
	CollectionService:AddTag(model, TAG)
	addBar(root, humanoid, kind, look)
	return model, humanoid, root
end

-- ---------------------------------------------------------------------------------------
-- Leaving the world
-- ---------------------------------------------------------------------------------------

local spawnSlot: (slotIndex: number) -> ()

-- Brings a den creature back after its kind's respawn time, unless it was respawned or
-- defeated again in the meantime.
local function scheduleRespawn(id: number, kind: CreatureKind)
	local slotIndex = World.creatureIndex(id)
	if slotIndex == nil then
		return
	end
	local generation = (generations[id] or 0) + 1
	generations[id] = generation
	task.delay(kind.respawn, function()
		if generations[id] == generation and creatures[id] == nil then
			spawnSlot(slotIndex)
		end
	end)
end

-- Takes the creature out of every registry. The model is left to the caller.
local function forget(creature: Creature)
	creature.gone = true
	if creatures[creature.id] == creature then
		creatures[creature.id] = nil
	end
	local entry = Fighters.get(creature.id)
	if entry ~= nil and entry.model == creature.model then
		Fighters.remove(creature.id)
		StatusService.drop(creature.id)
	end
end

-- Gone without a defeat (fell into the water, removed by something else, despawned): no
-- rewards. A den creature comes back on its timer when `respawn`.
local function remove(creature: Creature, respawn: boolean)
	if creature.gone then
		return
	end
	forget(creature)
	creature.model:Destroy()
	if respawn then
		scheduleRespawn(creature.id, creature.kind)
	end
end

-- Gone by drowning or falling out of the world, with no reward: a den creature is back at its den
-- at once, not after its full timer. A champion is simply gone.
local function removeLost(creature: Creature)
	if creature.gone then
		return
	end
	remove(creature, false)
	local slotIndex = World.creatureIndex(creature.id)
	if creature.owner == nil and slotIndex ~= nil then
		-- A pending timer from an earlier defeat must not spawn a second one.
		generations[creature.id] = (generations[creature.id] or 0) + 1
		spawnSlot(slotIndex)
	end
end

local function playerOf(id: number): Player?
	local entry = Fighters.get(id)
	return if entry ~= nil then entry.player else nil
end

-- Pays every contributor (Rewards decides who, what and which drops) and returns them.
local function payOut(creature: Creature, now: number): { Player }
	local kind = creature.kind
	local recipients: { [string]: Rewards.Recipient } = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data ~= nil then
			local room = Ledger.FREE_SLOTS - #data.ledger.free
			recipients[tostring(player.UserId)] = {
				calling = data.paths.calling,
				room = if LedgerService.isLocked(player) then 0 else math.max(0, room),
			}
		end
	end
	local held: { [string]: number } = {}
	for _, drop in kind.drops do
		held[drop.relicId] = SourceService.held(drop.relicId)
	end

	local contributors: { Player } = {}
	for _, award in Rewards.awards(kind, creature.tally, recipients, held, now, rng) do
		local player = playerOf(award.userId)
		if player == nil then
			continue
		end
		table.insert(contributors, player)
		LedgerService.notify(
			player,
			"CREATURE_DEFEATED",
			{ creature = kind.name, coin = tostring(award.coin) }
		)
		-- Every Relic the roll won goes to award(): it gives it, or says why not.
		local relics: { string } = {}
		for _, list in { award.relics, award.sealed, award.lost } do
			for _, relicId in list do
				table.insert(relics, relicId)
			end
		end
		Payout.give(
			player,
			{ coin = award.coin, xp = award.xp, path = award.xpPath, relics = relics }
		)
	end
	return contributors
end

local function onDied(creature: Creature)
	if creature.gone then
		return
	end
	local contributors: { Player } = {}
	-- A champion pays nothing and never comes back.
	if creature.owner == nil then
		local ok, result = pcall(payOut, creature, os.clock())
		if ok then
			contributors = result
		else
			warn(`[IsleOfAvarice] creature payout failed: {result}`)
		end
	end
	forget(creature)
	for _, callback in defeatCallbacks do
		local ok, err = pcall(callback, creature.kind.id, creature.id, contributors, creature.owner)
		if not ok then
			warn(`[IsleOfAvarice] onDefeated callback failed: {err}`)
		end
	end

	-- It tips over, then vanishes.
	local root, model = creature.root, creature.model
	root.Anchored = true
	root.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90))
	task.delay(TIP_SECONDS, function()
		model:Destroy()
	end)
	if creature.owner == nil then
		scheduleRespawn(creature.id, creature.kind)
	end
end

-- ---------------------------------------------------------------------------------------
-- Spawning
-- ---------------------------------------------------------------------------------------

local function spawn(id: number, kind: CreatureKind, den: Vec3, at: Vec3, owner: Player?)
	local old = creatures[id]
	if old ~= nil then
		remove(old, false)
	end
	local model, humanoid, root = buildModel(id, kind, at, owner)
	local creature: Creature = {
		id = id,
		kind = kind,
		den = den,
		owner = owner,
		model = model,
		humanoid = humanoid,
		root = root,
		brain = CreatureBrain.new(),
		tally = {},
		provoker = nil,
		parked = false,
		gone = false,
	}
	creatures[id] = creature
	model.Parent = folder()
	-- The server moves it: no client ever simulates a creature.
	root:SetNetworkOwner(nil)
	Fighters.add({
		id = id,
		kind = "creature",
		model = model,
		baseSpeed = kind.speed,
		owner = if owner ~= nil then owner.UserId else nil,
	})
	StatusService.reset(id)

	humanoid.Died:Connect(function()
		onDied(creature)
	end)
	-- Removed by anything else (fell out of the world): no rewards; a den creature returns.
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil and not creature.gone then
			removeLost(creature)
		end
	end)
end

function spawnSlot(slotIndex: number)
	local slot = World.creatureSlots[slotIndex]
	local den = World.dens[slot.den]
	local kind = Creatures.byId[slot.kind]
	if den == nil or kind == nil then
		return
	end
	-- Members stand in a ring around the den, MEMBER_SPACING apart.
	local member = 0
	for i = 1, slotIndex do
		if World.creatureSlots[i].den == slot.den then
			member += 1
		end
	end
	local at = den.position
	if den.count > 1 then
		local angle = (member - 1) / den.count * 2 * math.pi
		local radius = MEMBER_SPACING / (2 * math.sin(math.pi / den.count))
		at = {
			x = den.position.x + math.cos(angle) * radius,
			y = den.position.y,
			z = den.position.z + math.sin(angle) * radius,
		}
	end
	spawn(slot.id, kind, den.position, at, nil)
end

-- ---------------------------------------------------------------------------------------
-- Attacks
-- ---------------------------------------------------------------------------------------

-- True when the creature has a clear line to the target and it is within `reach` (level).
local function canReach(creature: Creature, targetId: number, reach: number): boolean
	local _, targetRoot = Fighters.body(targetId)
	if targetRoot == nil then
		return false
	end
	local from, to = creature.root.Position, targetRoot.Position
	return flat(from, to) <= reach and Sight.inSight(from, to, Fighters.model(targetId))
end

local function attack(creature: Creature, targetId: number)
	local kind = creature.kind
	local strike = kind.attack
	local id = creature.id
	if strike.kind == "slam" then
		-- Everyone near, not just the target.
		local self = Fighters.fighter(id)
		if self == nil then
			return
		end
		local feet = creature.root.Position - Vector3.new(0, creature.root.Size.Y / 2, 0)
		Fx.ring(feet + Vector3.new(0, 0.3, 0), strike.range, SLAM_COLOR)
		local others = Fighters.list(id)
		for _, otherId in Targeting.inRadius(self.position, others, strike.range, id) do
			local entry = Fighters.get(otherId)
			if
				entry ~= nil
				and entry.kind == "player"
				and canReach(creature, otherId, math.huge)
			then
				CombatService.damage(id, otherId, strike.damage)
			end
		end
		return
	end
	if not canReach(creature, targetId, strike.range + MELEE_SLACK) then
		return
	end
	if strike.kind == "shot" then
		local _, targetRoot = Fighters.body(targetId)
		if targetRoot ~= nil then
			Fx.ray(creature.root.Position, targetRoot.Position, SHOT_COLOR)
		end
	end
	CombatService.damage(id, targetId, strike.damage)
end

-- A dash at the target: it hits when the target is in the dash's path.
local function lunge(creature: Creature, targetId: number)
	local dash = creature.kind.lunge
	local target = Fighters.fighter(targetId)
	local self = Fighters.fighter(creature.id)
	if dash == nil or target == nil or self == nil then
		return
	end
	local dx, dz = target.position.x - self.position.x, target.position.z - self.position.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if not (distance > 0 and distance < math.huge) then
		return
	end
	dx, dz = dx / distance, dz / distance
	if
		not Sight.inSight(
			creature.root.Position,
			creature.root.Position + Vector3.new(dx, 0, dz) * distance,
			Fighters.model(targetId)
		)
	then
		return
	end
	local destination = CreatureBrain.outsideTown({
		x = self.position.x + dx * dash.distance,
		y = self.position.y,
		z = self.position.z + dz * dash.distance,
	})
	-- A dash never carries a creature off the land.
	local landX, landZ =
		Geography.landPath(self.position.x, self.position.z, destination.x, destination.z)
	destination = { x = landX, y = destination.y, z = landZ }
	local travelled = Sight.move(creature.humanoid, creature.root, destination)
	-- Judged from where the dash began, facing the way it went.
	local dasher: Combat.Fighter =
		{ id = creature.id, position = self.position, look = { x = dx, y = 0, z = dz } }
	if Targeting.dashHit(dasher, { target }, travelled + LUNGE_SLACK) == targetId then
		CombatService.damage(creature.id, targetId, dash.damage)
	end
end

-- ---------------------------------------------------------------------------------------
-- The brain loop
-- ---------------------------------------------------------------------------------------

type Sighted =
	{ id: number, player: Player, position: Vector3, character: Instance?, valid: boolean }

-- Every living player, and whether a creature may go for them at all.
local function sightedPlayers(now: number): { Sighted }
	local list: { Sighted } = {}
	for _, player in Players:GetPlayers() do
		local _, root = Fighters.body(player.UserId)
		if root == nil then
			continue
		end
		local status = ProtectionService.status(player, now)
		table.insert(list, {
			id = player.UserId,
			player = player,
			position = root.Position,
			character = player.Character,
			valid = status ~= nil and Protection.creatureCanHit(status, now),
		})
	end
	return list
end

local function think(creature: Creature, players: { Sighted }, now: number)
	local id, kind, humanoid, root = creature.id, creature.kind, creature.humanoid, creature.root
	local here = root.Position
	if here.Y < Geography.DROWN_Y then
		removeLost(creature)
		return
	end

	local seen: { CreatureBrain.Seen } = {}
	for _, other in players do
		-- A champion sees only its duellist.
		if creature.owner ~= nil and other.player ~= creature.owner then
			continue
		end
		local visible = other.valid
			and flat(here, other.position) <= kind.sight
			and Sight.inSight(here, other.position, other.character)
		table.insert(seen, {
			id = other.id,
			position = vec(other.position),
			visible = visible,
			valid = other.valid,
		})
	end

	local status = StatusService.get(id)
	local provoker = creature.provoker
	creature.provoker = nil
	local body: CreatureBrain.Body =
		{ position = vec(here), den = creature.den, rooted = Effects.isRooted(status, now) }
	local wasReturning = creature.brain.mode == "return"
	local decision = CreatureBrain.tick(
		kind,
		creature.brain,
		body,
		seen,
		Effects.tauntedBy(status, now),
		provoker,
		now,
		rng
	)
	creature.brain = decision.brain

	-- Walking home it cannot be hurt; once home it is whole again and owes nobody anything.
	if decision.brain.mode == "return" and not wasReturning then
		StatusService.update(id, function(current, at)
			return Effects.applyImmune(current, math.huge, at)
		end)
	end
	if decision.snapHome then
		-- It could not walk home in time (blocked by water or a wall): put it at its den.
		local ground = World.groundY + humanoid.HipHeight + root.Size.Y / 2
		root.CFrame = CFrame.new(creature.den.x, ground, creature.den.z) * root.CFrame.Rotation
		root.AssemblyLinearVelocity = Vector3.zero
		here = root.Position
	end
	if decision.home then
		humanoid.Health = humanoid.MaxHealth
		StatusService.reset(id)
		creature.tally = {}
	end

	local moveTo = decision.moveTo
	if moveTo ~= nil then
		humanoid:MoveTo(Vector3.new(moveTo.x, here.Y, moveTo.z))
	else
		humanoid:MoveTo(here)
		local faceTo = decision.faceTo
		if faceTo ~= nil then
			local at = Vector3.new(faceTo.x, here.Y, faceTo.z)
			if (at - here).Magnitude > 0.1 then
				root.CFrame = CFrame.lookAt(here, at)
			end
		end
	end

	local action = decision.action
	if action ~= nil then
		if action.kind == "lunge" then
			lunge(creature, action.targetId)
		else
			attack(creature, action.targetId)
		end
	end
end

local function runTick()
	local now = os.clock()
	local players = sightedPlayers(now)
	local set = active
	-- A snapshot: a defeat or a respawn mid-tick must not change the table under us.
	local list: { Creature } = {}
	for _, creature in creatures do
		table.insert(list, creature)
	end
	for _, creature in list do
		if creature.gone or creature.humanoid.Health <= 0 then
			continue
		end
		if set ~= nil and creature.owner == nil and not set[creature.id] then
			if not creature.parked then
				creature.parked = true
				creature.humanoid:MoveTo(creature.root.Position)
			end
			continue
		end
		creature.parked = false
		local ok, err = pcall(think, creature, players, now)
		if not ok then
			warn(`[IsleOfAvarice] creature {creature.id} failed to think: {err}`)
		end
	end
end

local function onHeartbeat(deltaTime: number)
	accumulated += deltaTime
	if accumulated < CreatureBrain.TICK_SECONDS then
		return
	end
	accumulated = 0
	runTick()
end

-- ---------------------------------------------------------------------------------------
-- Public
-- ---------------------------------------------------------------------------------------

-- Runs when a creature is defeated, after its rewards: the kind id, the creature id, the
-- players who were paid, and for a duel champion its duellist (with no contributors).
function CreatureService.onDefeated(callback: (
	kind: string,
	id: number,
	contributors: { Player },
	owner: Player?
) -> ())
	table.insert(defeatCallbacks, callback)
end

-- A Drowned Tallyman at `at` that only `owner` can fight. Returns its fighter id.
function CreatureService.spawnChampion(owner: Player, at: Vec3): number
	championCount += 1
	local id = World.CHAMPION_ID_BASE - championCount
	spawn(id, Creatures.byId.drowned_tallyman, at, at, owner)
	return id
end

-- Support that reached allies: every live den creature notes the helper as an assist when one of
-- `helpedIds` really hit it lately (Rewards.assist). Champions never take assists. Never yields.
function CreatureService.assist(helperId: number, helpedIds: { number }, path: string)
	local now = os.clock()
	for _, creature in creatures do
		if creature.owner == nil and not creature.gone then
			creature.tally = Rewards.assist(creature.tally, helperId, helpedIds, path, now)
		end
	end
end

-- Removes a creature: no rewards, no respawn.
function CreatureService.despawn(id: number)
	local creature = creatures[id]
	if creature ~= nil then
		remove(creature, false)
	end
end

-- Play-test seam. nil: every creature thinks. A list: only those den creatures think; the
-- rest stand still (champions always think).
function CreatureService.setActive(ids: { number }?)
	if ids == nil then
		active = nil
		return
	end
	local set: { [number]: boolean } = {}
	for _, id in ids do
		set[id] = true
	end
	active = set
end

-- Play-test seam: the source of wander and drop rolls.
function CreatureService.setRng(source: () -> number)
	rng = source
end

-- Play-test seam.
function CreatureService.info(id: number): Info?
	local creature = creatures[id]
	if creature == nil then
		local slotIndex = World.creatureIndex(id)
		if slotIndex == nil then
			return nil
		end
		return {
			kind = World.creatureSlots[slotIndex].kind,
			alive = false,
			mode = "",
			targetId = 0,
			position = nil,
			owner = nil,
		}
	end
	return {
		kind = creature.kind.id,
		alive = creature.humanoid.Health > 0,
		mode = creature.brain.mode,
		targetId = creature.brain.targetId,
		position = creature.root.Position,
		owner = creature.owner,
	}
end

-- Play-test seam: a den creature comes back now, at full health, at its den.
function CreatureService.respawn(id: number)
	local slotIndex = World.creatureIndex(id)
	if slotIndex == nil then
		return
	end
	generations[id] = (generations[id] or 0) + 1
	spawnSlot(slotIndex)
end

function CreatureService.start()
	folder()
	CombatService.onHit(function(attackerId, targetId, amount, path)
		local creature = creatures[targetId]
		if creature ~= nil and not creature.gone then
			creature.tally = Rewards.record(creature.tally, attackerId, path, amount, os.clock())
			creature.provoker = attackerId
		end
	end)
	for slotIndex in World.creatureSlots do
		spawnSlot(slotIndex)
	end
	RunService.Heartbeat:Connect(onHeartbeat)
end

return CreatureService
