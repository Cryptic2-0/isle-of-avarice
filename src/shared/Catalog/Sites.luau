--!strict
local Geography = require("../Rules/Geography")
local Regions = require("./Regions")
local Types = require("../Types")
local BastionReach = require("./SiteData/BastionReach")
local CinderFlats = require("./SiteData/CinderFlats")
local DrownedFen = require("./SiteData/DrownedFen")
local HushGardens = require("./SiteData/HushGardens")
local Make = require("./SiteData/Make")
local ReckoningRock = require("./SiteData/ReckoningRock")
local Scenery = require("./SiteData/Scenery")
local SquallSteps = require("./SiteData/SquallSteps")
local Thornwood = require("./SiteData/Thornwood")

-- In the order the sites were added.
local list: { Types.Site } = {
	Thornwood,
	SquallSteps,
	CinderFlats,
	DrownedFen,
	ReckoningRock,
	HushGardens,
	BastionReach,
}

local hazards: { Types.Hazard } = {}
local hazardById: { [string]: Types.Hazard } = {}
local features: { Types.Feature } = {}
local siteByRegion: { [string]: Types.Site } = {}
for _, site in list do
	siteByRegion[site.region] = site
	for _, hazard in site.hazards do
		table.insert(hazards, hazard)
		hazardById[hazard.id] = hazard
	end
	for _, feature in site.features do
		table.insert(features, feature)
	end
end

-- A road from the Fields to each wild region's site, a signpost beside it, and the bridges.
local common: { Types.Feature } = {}
for _, regionId in Regions.wild do
	local region = Regions.byId[regionId]
	table.insert(common, Make.block(regionId, 45, 470, -6, 6, 0.02, 0.12, "road", false))
	table.insert(common, Make.disc(regionId, 285, 14, 0.5, 0, 7, "sign", true))
	local board = Make.block(regionId, 284.5, 285.5, 10, 18, 5, 8, "sign", false)
	board.text = region.name .. "\n" .. region.hint
	table.insert(common, board)
end
for _, bridge in Geography.bridges() do
	table.insert(common, {
		look = "wood",
		shape = "block",
		x = bridge.x,
		y = -0.7,
		z = bridge.z,
		sx = bridge.width,
		sy = 2,
		sz = bridge.length,
		yaw = bridge.yaw,
		solid = true,
	})
end

-- Props scattered over each wild region.
local scenery: { Types.Feature } = {}
for index, regionId in Regions.wild do
	for _, feature in Scenery.scatter(siteByRegion[regionId], index) do
		table.insert(scenery, feature)
	end
end

-- Off the road in each wild region, a Copper cache holding Relics R001 to R006 in turn.
local extras: { Types.SiteCache } = {}
for k, regionId in Regions.wild do
	local x, z = Geography.place(regionId, 310, -60)
	table.insert(extras, { relicId = string.format("R%03d", k), x = x, y = 1, z = z })
end

-- Every site's features, then the common ones, then the scenery.
for _, feature in common do
	table.insert(features, feature)
end
for _, feature in scenery do
	table.insert(features, feature)
end

return {
	list = list,
	hazards = hazards,
	hazardById = hazardById,
	features = features,
	common = common,
	scenery = scenery,
	extras = extras,
}
