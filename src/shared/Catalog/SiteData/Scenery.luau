--!strict
local Geography = require("../../Rules/Geography")
local Hazards = require("../../Rules/Hazards")
local Types = require("../../Types")
local Make = require("./Make")

local Scenery = {}

local TRIES = 400
local PROPS = 36
local SEED_BASE = 1000
local MIN_ALONG = 300
local ALONG_SPAN = 600
local CLEARANCE = 12 -- a prop's footprint is checked this far out in each direction
local ROAD_HALF_WIDTH = 16
local ROAD_END = 480
local CACHE_CLEARANCE = 30
-- Where Sites puts the region's extra Copper cache.
local COPPER_ALONG = 310
local COPPER_ACROSS = -60

-- One piece of a prop: a block sx across by sz along, or a cylinder of diameter sx = sz, standing
-- on the piece below it. Heights are multiplied by the prop's scale.
type Part = {
	shape: "block" | "cylinder",
	sx: number,
	sz: number,
	height: number,
	look: string,
	solid: boolean,
}
type Kind = { Part }

local function cylinder(diameter: number, height: number, look: string, solid: boolean): Part
	return {
		shape = "cylinder",
		sx = diameter,
		sz = diameter,
		height = height,
		look = look,
		solid = solid,
	}
end

local function block(sx: number, sz: number, height: number, look: string, solid: boolean): Part
	return { shape = "block", sx = sx, sz = sz, height = height, look = look, solid = solid }
end

local deadTree: Kind = { cylinder(2.5, 16, "deadwood", true) }

local kindsByRegion: { [string]: { Kind } } = {
	Thornwood = {
		{ cylinder(3, 14, "trunk", true), cylinder(14, 8, "leaf", false) },
		{ cylinder(8, 4, "leaf", true) },
	},
	SquallSteps = {
		{ block(6, 6, 18, "pillar", true) },
		{ block(8, 8, 5, "rock", true) },
	},
	CinderFlats = {
		{ cylinder(6, 12, "basalt", true) },
		{ cylinder(14, 3, "basalt", true) },
	},
	DrownedFen = {
		deadTree,
		{ cylinder(10, 5, "reed", false) },
	},
	HushGardens = {
		deadTree,
		{ cylinder(12, 0.4, "flower", false) },
	},
	BastionReach = {
		{ block(8, 6, 4, "rubble", true) },
		{ cylinder(4, 10, "wall", true) },
	},
}

-- Land of the site's own region, clear of its keep-out shapes and of every hazard that has a
-- footprint of its own.
local function usable(site: Types.Site, x: number, z: number): boolean
	if not Geography.isLand(x, z) or Geography.regionAt(x, z) ~= site.region then
		return false
	end
	for _, shape in site.keepOut do
		if Hazards.contains(shape, x, z) then
			return false
		end
	end
	for _, hazard in site.hazards do
		if hazard.shape.kind ~= "region" and Hazards.affects(hazard, x, z) then
			return false
		end
	end
	return true
end

-- The features of one prop standing at (along, across), its parts stacked from the ground up.
local function build(
	region: string,
	kind: Kind,
	along: number,
	across: number,
	scale: number
): { Types.Feature }
	local features: { Types.Feature } = {}
	local base = 0
	for _, part in kind do
		local top = base + part.height * scale
		if part.shape == "cylinder" then
			table.insert(
				features,
				Make.disc(region, along, across, part.sx / 2, base, top, part.look, part.solid)
			)
		else
			table.insert(
				features,
				Make.block(
					region,
					along - part.sz / 2,
					along + part.sz / 2,
					across - part.sx / 2,
					across + part.sx / 2,
					base,
					top,
					part.look,
					part.solid
				)
			)
		end
		base = top
	end
	return features
end

-- Trees, rocks and the like scattered over a wild region, the same every time. index is the
-- region's place in Regions.wild; it seeds the pseudo-random sequence.
function Scenery.scatter(site: Types.Site, index: number): { Types.Feature }
	local kinds = kindsByRegion[site.region]
	if kinds == nil then
		error(`Scenery: region {site.region} has no scenery`)
	end

	local seed = SEED_BASE + index
	local function draw(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end

	-- The caches no prop may crowd: the site's prize, if it has one, and the Copper cache.
	local caches: { { number } } = {}
	local prize = site.prize
	if prize ~= nil then
		table.insert(caches, { prize.x, prize.z })
	end
	local copperX, copperZ = Geography.place(site.region, COPPER_ALONG, COPPER_ACROSS)
	table.insert(caches, { copperX, copperZ })

	local features: { Types.Feature } = {}
	local placed = 0
	for _ = 1, TRIES do
		if placed >= PROPS then
			break
		end
		-- Four draws a try, whether or not the spot is used.
		local along = MIN_ALONG + ALONG_SPAN * draw()
		local across = (2 * draw() - 1) * 0.5 * along
		local kind = kinds[math.floor(draw() * #kinds) + 1]
		local scale = 0.8 + 0.6 * draw()

		local onRoad = math.abs(across) < ROAD_HALF_WIDTH and along < ROAD_END
		local nearCache = false
		local x, z = Geography.place(site.region, along, across)
		for _, point in caches do
			if math.sqrt((x - point[1]) ^ 2 + (z - point[2]) ^ 2) <= CACHE_CLEARANCE then
				nearCache = true
			end
		end

		local ok = not onRoad and not nearCache and usable(site, x, z)
		if ok then
			for _, offset in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local px, pz = Geography.place(
					site.region,
					along + offset[1] * CLEARANCE,
					across + offset[2] * CLEARANCE
				)
				if not usable(site, px, pz) then
					ok = false
					break
				end
			end
		end

		if ok then
			placed += 1
			for _, feature in build(site.region, kind, along, across, scale) do
				table.insert(features, feature)
			end
		end
	end
	return features
end

return Scenery
