--!strict
local Geography = require("../../Rules/Geography")
local Types = require("../../Types")
local Make = require("./Make")

local REGION: Types.RegionId = "DrownedFen"
local BOARDWALK_TOP = 0.6

-- along from, along to, across from, across to. The two long walks run down the middle with a
-- rotted gap between them; the three short ones lead off to the east.
local BOARDWALKS = {
	{ 400, 620, -7, 7 },
	{ 680, 860, -7, 7 },
	{ 493, 507, 7, 150 },
	{ 493, 707, 143, 157 },
	{ 693, 707, 7, 150 },
}

local bog = Geography.rect(REGION, 400, 860, -180, 200)

local holes: { Types.Shape } = {}
local features: { Types.Feature } = {}
for _, walk in BOARDWALKS do
	table.insert(holes, Geography.rect(REGION, walk[1], walk[2], walk[3], walk[4]))
	table.insert(
		features,
		Make.block(REGION, walk[1], walk[2], walk[3], walk[4], 0, BOARDWALK_TOP, "wood", true)
	)
end

local site: Types.Site = {
	region = REGION,
	hazards = {
		{
			id = "FenBog",
			region = REGION,
			name = "Bog",
			look = "bog",
			shape = bog,
			holes = holes,
			slow = 0.5,
			dps = 3,
		},
	},
	features = features,
	prize = nil,
	keepOut = { bog },
}

return site
