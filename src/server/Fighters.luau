--!strict
-- The registry of everything that fights, by numeric fighter id: players (their UserId),
-- training posts (World.POST_ID_BASE - i) and, from Task 9, creatures. Never infer a kind
-- from an id's sign: ask Fighters.get(id).kind.
--   Fighters.start()              players on join and leave; every TrainingPost part with a
--                                 valid PostId, now and when tagged later
--   Fighters.add(entry)           replaces any entry with the same id
--   Fighters.remove(id)
--   Fighters.get(id): Entry?
--   Fighters.all(): { Entry }     every entry: players, then posts, then creatures
--   Fighters.model(id)            character, post part or creature model
--   Fighters.body(id)             living Humanoid and root of a player or creature
--   Fighters.fighter(id)          Combat.Fighter at the root (posts: the part, look +z)
--   Fighters.list(viewer)         every other living fighter the viewer may fight
--   Fighters.mayFight(a, b)       whether `a` may hit `b`
-- Requires only Roblox services and shared modules, so every server service may require it.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Rules.Combat)
local World = require(ReplicatedStorage.Shared.Catalog.World)

export type Kind = "player" | "post" | "creature"
export type Entry = {
	id: number,
	kind: Kind,
	player: Player?, -- kind "player"
	-- A post part or creature model; a player's is read live from player.Character.
	model: Instance?,
	-- WalkSpeed with no slow or root: players 16, posts 0, creatures their catalog speed.
	baseSpeed: number,
	-- Creatures only: the one fighter id that may hit it or be hit by it (duel champion).
	owner: number?,
}

local POST_TAG = "TrainingPost"
local PLAYER_SPEED = 16
local KIND_ORDER: { Kind } = { "player", "post", "creature" }

local Fighters = {}

local entries: { [number]: Entry } = {}
-- Ids in the order they were first added, so lists come out in a stable order.
local order: { number } = {}

function Fighters.add(entry: Entry)
	if entries[entry.id] == nil then
		table.insert(order, entry.id)
	end
	entries[entry.id] = entry
end

function Fighters.remove(id: number)
	if entries[id] == nil then
		return
	end
	entries[id] = nil
	local index = table.find(order, id)
	if index ~= nil then
		table.remove(order, index)
	end
end

function Fighters.get(id: number): Entry?
	return entries[id]
end

-- Every entry, players first, then posts, then creatures, each in the order they were added.
function Fighters.all(): { Entry }
	local result: { Entry } = {}
	for _, kind in KIND_ORDER do
		for _, id in order do
			local entry = entries[id]
			if entry ~= nil and entry.kind == kind then
				table.insert(result, entry)
			end
		end
	end
	return result
end

function Fighters.model(id: number): Instance?
	local entry = entries[id]
	if entry == nil then
		return nil
	end
	if entry.kind == "player" then
		local player = entry.player
		return if player ~= nil then player.Character else nil
	end
	return entry.model
end

-- The Humanoid and HumanoidRootPart of a living player or creature, or nil.
function Fighters.body(id: number): (Humanoid?, BasePart?)
	local entry = entries[id]
	if entry == nil or entry.kind == "post" then
		return nil, nil
	end
	local model = Fighters.model(id)
	if model == nil then
		return nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil, nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root
end

-- A living fighter's position and facing; health for players and creatures, none for posts.
-- Nil for a dead player or creature, and for a post whose part is not in the world.
function Fighters.fighter(id: number): Combat.Fighter?
	local entry = entries[id]
	if entry == nil then
		return nil
	end
	if entry.kind == "post" then
		local model = entry.model
		if model == nil or not model:IsA("BasePart") or not model:IsDescendantOf(workspace) then
			return nil
		end
		local p = (model :: BasePart).Position
		return {
			id = id,
			position = { x = p.X, y = p.Y, z = p.Z },
			look = { x = 0, y = 0, z = 1 },
		}
	end
	local humanoid, root = Fighters.body(id)
	if humanoid == nil or root == nil then
		return nil
	end
	local p = root.Position
	local look = root.CFrame.LookVector
	return {
		id = id,
		position = { x = p.X, y = p.Y, z = p.Z },
		look = { x = look.X, y = look.Y, z = look.Z },
		health = humanoid.Health,
	}
end

-- False for a fighter against itself, for an unknown id, for a post attacker, and when
-- either side has an owner that is not the other.
function Fighters.mayFight(a: number, b: number): boolean
	if a == b then
		return false
	end
	local attacker, target = entries[a], entries[b]
	if attacker == nil or target == nil or attacker.kind == "post" then
		return false
	end
	if attacker.owner ~= nil and attacker.owner ~= b then
		return false
	end
	if target.owner ~= nil and target.owner ~= a then
		return false
	end
	return true
end

-- Every other living fighter `viewer` may fight, posts included: players first, then posts,
-- then creatures.
function Fighters.list(viewer: number): { Combat.Fighter }
	local result: { Combat.Fighter } = {}
	for _, entry in Fighters.all() do
		if not Fighters.mayFight(viewer, entry.id) then
			continue
		end
		local fighter = Fighters.fighter(entry.id)
		if fighter ~= nil then
			table.insert(result, fighter)
		end
	end
	return result
end

local function postIdOf(instance: Instance): number?
	local id = instance:GetAttribute("PostId")
	if instance:IsA("BasePart") and type(id) == "number" and World.postIndex(id) ~= nil then
		return id
	end
	return nil
end

local function addPost(instance: Instance)
	local id = postIdOf(instance)
	if id ~= nil then
		Fighters.add({ id = id, kind = "post", model = instance, baseSpeed = 0 })
	end
end

local function removePost(instance: Instance)
	local id = postIdOf(instance)
	if id == nil then
		return
	end
	local entry = entries[id]
	if entry ~= nil and entry.model == instance then
		Fighters.remove(id)
	end
end

local function addPlayer(player: Player)
	Fighters.add({ id = player.UserId, kind = "player", player = player, baseSpeed = PLAYER_SPEED })
end

function Fighters.start()
	Players.PlayerAdded:Connect(addPlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- Only this Player's own entry: a rejoin under the same UserId may already own the id.
		local entry = entries[player.UserId]
		if entry ~= nil and entry.player == player then
			Fighters.remove(player.UserId)
		end
	end)

	-- Posts in index order, so lists keep the catalog order.
	local tagged = CollectionService:GetTagged(POST_TAG)
	table.sort(tagged, function(a, b)
		local ia = World.postIndex(postIdOf(a) or 0) or math.huge
		local ib = World.postIndex(postIdOf(b) or 0) or math.huge
		return ia < ib
	end)
	for _, instance in tagged do
		addPost(instance)
	end
	CollectionService:GetInstanceAddedSignal(POST_TAG):Connect(addPost)
	CollectionService:GetInstanceRemovedSignal(POST_TAG):Connect(removePost)
end

return Fighters
