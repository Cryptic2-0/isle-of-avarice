--!strict
-- Builds the island's ground and the sea around it.
--   TerrainBuilder.build(island)
--       Adds Folder "Ground" (one Part per strip from Geography.strips(), painted with its
--       region's ground look) and Folder "Sea" (four Parts) to `island`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Geography = require(ReplicatedStorage.Shared.Rules.Geography)
local Regions = require(ReplicatedStorage.Shared.Catalog.Regions)
local World = require(ReplicatedStorage.Shared.Catalog.World)
local LookPainter = require(script.Parent.LookPainter)

local TerrainBuilder = {}

local GROUND_THICKNESS = 4
-- A Part cannot be larger than 2048 studs on a side, so the sea is four of them, one per
-- quadrant, together covering -2048 to 2048 in x and z.
local SEA_SIZE = 2048
local SEA_THICKNESS = 2
local SEA_CENTER_Y = -4
local SEA_COLOR = Color3.fromRGB(40, 100, 170)
local SEA_TRANSPARENCY = 0.3

local function buildGround(island: Folder)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	for _, strip in Geography.strips() do
		local region = Regions.byId[strip.region]
		local part = Instance.new("Part")
		part.Name = "Ground"
		part.Anchored = true
		part.Size = Vector3.new(strip.x2 - strip.x1, GROUND_THICKNESS, Geography.CELL)
		-- Block centres are half a height below the top face.
		part.CFrame =
			CFrame.new((strip.x1 + strip.x2) / 2, World.groundY - GROUND_THICKNESS / 2, strip.z)
		LookPainter.paint(part, if region then region.ground else "")
		part.Parent = ground
	end
	ground.Parent = island
end

local function buildSea(island: Folder)
	local sea = Instance.new("Folder")
	sea.Name = "Sea"
	for _, signX in { -1, 1 } do
		for _, signZ in { -1, 1 } do
			local part = Instance.new("Part")
			part.Name = "Sea"
			part.Anchored = true
			part.Size = Vector3.new(SEA_SIZE, SEA_THICKNESS, SEA_SIZE)
			part.CFrame = CFrame.new(signX * SEA_SIZE / 2, SEA_CENTER_Y, signZ * SEA_SIZE / 2)
			part.Color = SEA_COLOR
			part.Material = Enum.Material.Glass
			part.Transparency = SEA_TRANSPARENCY
			part.CanCollide = false
			part.Parent = sea
		end
	end
	sea.Parent = island
end

function TerrainBuilder.build(island: Folder)
	buildGround(island)
	buildSea(island)
end

return TerrainBuilder
