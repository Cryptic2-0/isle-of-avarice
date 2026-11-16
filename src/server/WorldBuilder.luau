--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Creatures = require(ReplicatedStorage.Shared.Catalog.Creatures)
local Relics = require(ReplicatedStorage.Shared.Catalog.Relics)
local Tiers = require(ReplicatedStorage.Shared.Catalog.Tiers)
local Trials = require(ReplicatedStorage.Shared.Catalog.Trials)
local Types = require(ReplicatedStorage.Shared.Types)
local World = require(ReplicatedStorage.Shared.Catalog.World)
local SiteBuilder = require(script.Parent.SiteBuilder)
local TerrainBuilder = require(script.Parent.TerrainBuilder)

local WorldBuilder = {}

local STONE = Color3.fromRGB(150, 146, 140)
local ROCK = Color3.fromRGB(110, 110, 112)
local WOOD = Color3.fromRGB(139, 100, 60)
local WALL = Color3.fromRGB(170, 150, 120)
local LEDGE = Color3.fromRGB(96, 100, 110)
local DEN = Color3.fromRGB(52, 46, 40)
local MARKER = Color3.fromRGB(120, 230, 255)
local SKIN = Color3.fromRGB(232, 200, 160)
local CLERK_ROBE = Color3.fromRGB(70, 40, 100)
local WARDEN_COLORS: { [string]: Color3 } = {
	tidewalk = Color3.fromRGB(40, 110, 160),
	gullstep_climb = Color3.fromRGB(150, 160, 175),
	salt_post = Color3.fromRGB(225, 225, 215),
	cull_the_pack = Color3.fromRGB(120, 60, 50),
	shellbreaker = Color3.fromRGB(190, 160, 100),
	tallymans_duel = Color3.fromRGB(30, 80, 80),
}
-- The west Sluice begins here; the Harbour Warden's dock points at it.
local SLUICE_HEAD = Vector3.new(-330, 0, 30)

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
	-- No default spawn force field: ProtectionService gives the respawn shield instead.
	spawnPad.Duration = 0
	spawnPad.Parent = town

	-- Safe-zone marker: a flat disc over the plaza. A Roblox cylinder's axis is X,
	-- so it is turned a quarter about Z to lie flat. Plaza top is groundY + 0.2.
	local disc = Instance.new("Part")
	disc.Name = "SafeZone"
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanTouch = false
	disc.CanQuery = false
	disc.Size = Vector3.new(0.05, World.townRadius * 2, World.townRadius * 2)
	disc.CFrame = CFrame.new(0, World.groundY + 0.2 + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = Color3.fromRGB(255, 225, 140)
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.8
	disc.Parent = town

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

local function buildCache(island: Folder, index: number, cache: Types.Cache)
	local relic = Relics.byId[cache.relicId]
	local c = Tiers.info[relic.tier].color
	local color = Color3.fromRGB(c.r, c.g, c.b)
	local p = cache.position
	-- The cache is 2 tall and its position is its centre, so the floor it stands on is 1 below.
	-- Most caches stand on the ground; a few stand on a raised floor of their own.
	local base = p.y - 1

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

	-- Pillar is 12 tall, standing on the cache's own floor 3 studs to the side.
	makePart(
		part,
		"Pillar",
		Vector3.new(1, 12, 1),
		Vector3.new(p.x + 3, base + 6, p.z),
		color,
		Enum.Material.Neon
	)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Cache"
	prompt.HoldDuration = cache.hold or 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	-- Landmark rock: size depends only on the index, so every build is identical. Only a cache
	-- near the ground has one; a raised cache already stands out.
	if base < 1 then
		local w = 4 + (index % 3) * 2
		local h = 3 + (index % 4)
		local d = 4 + (index % 2) * 3
		makePart(
			island,
			"Rock" .. cache.id,
			Vector3.new(w, h, d),
			Vector3.new(p.x - 8, base + h / 2, p.z + 5),
			ROCK,
			Enum.Material.Slate
		)
	end
end

local function buildPost(island: Folder, index: number, position: Types.Vec3)
	-- 6 tall, standing on the ground.
	local part = makePart(
		island,
		"Post" .. index,
		Vector3.new(2, 6, 2),
		Vector3.new(position.x, World.groundY + 3, position.z),
		WOOD,
		Enum.Material.Wood
	)
	part:SetAttribute("PostId", World.POST_ID_BASE - index)
	CollectionService:AddTag(part, "TrainingPost")

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 30)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Training post"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	gui.Parent = part
end

-- A flat disc lying on the ground. A Roblox cylinder's axis is X, so it is turned a quarter
-- about Z. Characters walk and rays pass through it unless `solid`.
local function makeDisc(
	parent: Instance,
	name: string,
	radius: number,
	position: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	solid: boolean
): Part
	local disc = Instance.new("Part")
	disc.Name = name
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = solid
	disc.CanTouch = false
	disc.CanQuery = solid
	disc.Size = Vector3.new(thickness, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = color
	disc.Material = material
	disc.Parent = parent
	return disc
end

local function makeLabel(parent: Instance, text: string, lift: number, maxDistance: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 44)
	gui.StudsOffset = Vector3.new(0, lift, 0)
	gui.MaxDistance = maxDistance
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	gui.Parent = parent
end

-- The Edict Hall clerk: a figure behind a low counter, with a "Shop" prompt. ShopService
-- finds the body by its tag. The counter is on the plaza side, towards the centre.
local function buildClerk(island: Folder)
	local town = island:FindFirstChild("Tallyport") or island
	local at = World.clerk
	local model = Instance.new("Model")
	model.Name = "EdictHallClerk"
	local body = makePart(
		model,
		"Body",
		Vector3.new(2, 4, 1.5),
		Vector3.new(at.x, at.y + 2, at.z),
		CLERK_ROBE,
		Enum.Material.SmoothPlastic
	)
	local head = makePart(
		model,
		"Head",
		Vector3.new(1.6, 1.6, 1.6),
		Vector3.new(at.x, at.y + 4.8, at.z),
		SKIN,
		Enum.Material.SmoothPlastic
	)
	head.Shape = Enum.PartType.Ball
	makePart(
		model,
		"Counter",
		Vector3.new(6, 3, 2),
		Vector3.new(at.x, at.y + 1.5, at.z + 2.5),
		WOOD,
		Enum.Material.Wood
	)
	model.PrimaryPart = body
	CollectionService:AddTag(body, "ShopClerk")
	makeLabel(body, "Edict Hall\nPacks, Copper Relics, selling", 5.5, 80)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Shop"
	prompt.ObjectText = "Edict Hall clerk"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	model.Parent = town
end

-- A climb ledge: a rock block from the ground up to its top.
local function buildLedge(island: Folder, ledge: Types.Ledge)
	makePart(
		island,
		"Ledge",
		Vector3.new(ledge.size, ledge.top, ledge.size),
		Vector3.new(ledge.x, World.groundY + ledge.top / 2, ledge.z),
		LEDGE,
		Enum.Material.Slate
	)
end

-- A Warden: a small figure with a "Talk" prompt. TrialService finds the body by its tag.
local function buildWarden(island: Folder, trial: Types.Trial, position: Types.Vec3)
	local model = Instance.new("Model")
	model.Name = "Warden_" .. trial.id
	local color = WARDEN_COLORS[trial.id] or WOOD
	local body = makePart(
		model,
		"Body",
		Vector3.new(2, 4, 1.5),
		Vector3.new(position.x, World.groundY + 2, position.z),
		color,
		Enum.Material.SmoothPlastic
	)
	local head = makePart(
		model,
		"Head",
		Vector3.new(1.6, 1.6, 1.6),
		Vector3.new(position.x, World.groundY + 4.8, position.z),
		SKIN,
		Enum.Material.SmoothPlastic
	)
	head.Shape = Enum.PartType.Ball
	model.PrimaryPart = body
	body:SetAttribute("TrialId", trial.id)
	CollectionService:AddTag(body, "Warden")
	makeLabel(body, trial.warden .. "\nTrial: " .. trial.name, 5.5, 80)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = trial.warden
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	model.Parent = island
end

-- A course marker: a glowing ring on the surface under the marker, with its number.
local function buildMarker(island: Folder, trialId: string, index: number, marker: Types.Vec3)
	-- Markers are at standing-root height, 3 above the surface.
	local ring = makeDisc(
		island,
		"TrialMarker",
		3,
		Vector3.new(marker.x, marker.y - 3 + 0.15, marker.z),
		0.1,
		MARKER,
		Enum.Material.Neon,
		false
	)
	ring.Transparency = 0.3
	ring:SetAttribute("TrialId", trialId)
	ring:SetAttribute("Index", index)
	CollectionService:AddTag(ring, "TrialMarker")
	makeLabel(ring, tostring(index), 3, 60)
end

local function buildDen(island: Folder, den: Types.Den)
	local kind = Creatures.byId[den.kind]
	local patch = makeDisc(
		island,
		"Den",
		8,
		Vector3.new(den.position.x, World.groundY + 0.25, den.position.z),
		0.1,
		DEN,
		Enum.Material.Ground,
		false
	)
	makeLabel(patch, (if kind ~= nil then kind.name else den.kind) .. " den", 4, 60)
end

-- The M4 world: climbs, Wardens, course markers, the harbour dock, the duel arena and dens.
local function buildTrialsAndDens(island: Folder)
	for _, ledges in World.climbs do
		for _, ledge in ledges do
			buildLedge(island, ledge)
		end
	end
	for _, trial in Trials.list do
		local position = World.wardens[trial.id]
		if position ~= nil then
			buildWarden(island, trial, position)
		end
	end
	for trialId, markers in World.courses do
		for index, marker in markers do
			buildMarker(island, trialId, index, marker)
		end
	end

	local harbour = Vector3.new(World.harbour.x, World.groundY, World.harbour.z)
	local toward = (SLUICE_HEAD - harbour).Unit
	local dock =
		makePart(island, "Dock", Vector3.new(8, 1, 30), harbour, WOOD, Enum.Material.WoodPlanks)
	local dockCentre = harbour + toward * 20 + Vector3.new(0, 0.5, 0)
	dock.CFrame = CFrame.lookAt(dockCentre, dockCentre + toward)

	makeDisc(
		island,
		"DuelArena",
		25,
		Vector3.new(World.duelArena.x, World.groundY + 0.1, World.duelArena.z),
		0.2,
		STONE,
		Enum.Material.Cobblestone,
		true
	)
	for _, den in World.dens do
		buildDen(island, den)
	end
end

function WorldBuilder.build()
	local island = Instance.new("Folder")
	island.Name = "Island"
	TerrainBuilder.build(island)
	SiteBuilder.build(island)
	buildTallyport(island)
	buildClerk(island)
	for i, cache in World.caches do
		buildCache(island, i, cache)
	end
	for i, position in World.trainingPosts do
		buildPost(island, i, position)
	end
	buildTrialsAndDens(island)
	island.Parent = workspace
end

return WorldBuilder
