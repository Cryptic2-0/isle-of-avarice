--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Relics = require(ReplicatedStorage.Shared.Catalog.Relics)
local Tiers = require(ReplicatedStorage.Shared.Catalog.Tiers)
local World = require(ReplicatedStorage.Shared.Catalog.World)

local WorldBuilder = {}

local GRASS = Color3.fromRGB(86, 140, 60)
local SEA = Color3.fromRGB(40, 100, 170)
local STONE = Color3.fromRGB(150, 146, 140)
local ROCK = Color3.fromRGB(110, 110, 112)
local WALL = Color3.fromRGB(170, 150, 120)

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

local function buildTerrain(island: Folder)
	-- Block centres are half a height below the top face.
	makePart(
		island,
		"Ground",
		Vector3.new(World.islandHalfSize * 2, 4, World.islandHalfSize * 2),
		Vector3.new(0, World.groundY - 2, 0),
		GRASS,
		Enum.Material.Grass
	)
	local sea = makePart(
		island,
		"Sea",
		Vector3.new(2048, 2, 2048),
		Vector3.new(0, -3 - 1, 0),
		SEA,
		Enum.Material.Glass
	)
	sea.Transparency = 0.3
	sea.CanCollide = false
end

local function buildTallyport(island: Folder)
	local town = Instance.new("Folder")
	town.Name = "Tallyport"

	makePart(
		town,
		"Plaza",
		Vector3.new(80, 0.2, 80),
		Vector3.new(0, World.groundY + 0.1, 0),
		STONE,
		Enum.Material.Cobblestone
	)

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Anchored = true
	spawnPad.Neutral = true
	spawnPad.Size = Vector3.new(6, 1, 6)
	spawnPad.CFrame = CFrame.new(World.spawn.x, World.spawn.y, World.spawn.z)
	spawnPad.Parent = town

	-- Four buildings of different sizes at the plaza corners (width, height, depth).
	local buildings = {
		{ x = -28, z = -28, w = 16, h = 12, d = 14 },
		{ x = 28, z = -28, w = 12, h = 18, d = 12 },
		{ x = -28, z = 28, w = 14, h = 9, d = 18 },
		{ x = 28, z = 28, w = 18, h = 14, d = 16 },
	}
	for i, b in buildings do
		makePart(
			town,
			"Building" .. i,
			Vector3.new(b.w, b.h, b.d),
			Vector3.new(b.x, World.groundY + b.h / 2, b.z),
			WALL,
			Enum.Material.Brick
		)
	end
	town.Parent = island
end

local function buildCache(island: Folder, index: number, cache: any)
	local relic = Relics.byId[cache.relicId]
	local c = Tiers.info[relic.tier].color
	local color = Color3.fromRGB(c.r, c.g, c.b)
	local p = cache.position

	local part = makePart(
		island,
		cache.id,
		Vector3.new(2, 2, 2),
		Vector3.new(p.x, p.y, p.z),
		color,
		Enum.Material.SmoothPlastic
	)
	part:SetAttribute("CacheId", cache.id)
	CollectionService:AddTag(part, "Cache")

	-- Pillar is 12 tall, standing on the ground 3 studs to the side.
	makePart(
		part,
		"Pillar",
		Vector3.new(1, 12, 1),
		Vector3.new(p.x + 3, World.groundY + 6, p.z),
		color,
		Enum.Material.Neon
	)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Cache"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	-- Landmark rock: size depends only on the index, so every build is identical.
	local w = 4 + (index % 3) * 2
	local h = 3 + (index % 4)
	local d = 4 + (index % 2) * 3
	makePart(
		island,
		"Rock" .. cache.id,
		Vector3.new(w, h, d),
		Vector3.new(p.x - 8, World.groundY + h / 2, p.z + 5),
		ROCK,
		Enum.Material.Slate
	)
end

function WorldBuilder.build()
	local island = Instance.new("Folder")
	island.Name = "Island"
	buildTerrain(island)
	buildTallyport(island)
	for i, cache in World.caches do
		buildCache(island, i, cache)
	end
	island.Parent = workspace
end

return WorldBuilder
