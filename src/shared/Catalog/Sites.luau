--!strict
local Types = require("../Types")
local SquallSteps = require("./SiteData/SquallSteps")
local Thornwood = require("./SiteData/Thornwood")

-- In the order the sites were added.
local list: { Types.Site } = {
	Thornwood,
	SquallSteps,
}

local hazards: { Types.Hazard } = {}
local hazardById: { [string]: Types.Hazard } = {}
local features: { Types.Feature } = {}
for _, site in list do
	for _, hazard in site.hazards do
		table.insert(hazards, hazard)
		hazardById[hazard.id] = hazard
	end
	for _, feature in site.features do
		table.insert(features, feature)
	end
end

return {
	list = list,
	hazards = hazards,
	hazardById = hazardById,
	features = features,
}
