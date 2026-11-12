--!strict
local Geography = require("../../Rules/Geography")
local Types = require("../../Types")

local REGION: Types.RegionId = "HushGardens"
local SPRING_RADIUS = 14
local KEEP_OUT_RADIUS = 20

-- along, across.
local springs = {
	{ 380, 0 },
	{ 470, 0 },
	{ 560, 0 },
	{ 650, 0 },
	{ 740, 0 },
	{ 450, -120 },
	{ 560, 140 },
	{ 660, -150 },
	{ 790, 130 },
}

-- The blight must come first: a point in both reads "Blight" then "Spring".
local hazards: { Types.Hazard } = {
	{
		id = "HushBlight",
		region = REGION,
		name = "Blight",
		look = "none",
		shape = Geography.regionShape(REGION, 330),
		dps = 5,
	},
}
local keepOut: { Types.Shape } = {}
for i, spring in springs do
	table.insert(hazards, {
		id = `HushSpring{i}`,
		region = REGION,
		name = "Spring",
		look = "spring",
		shape = Geography.circle(REGION, spring[1], spring[2], SPRING_RADIUS),
		heal = 15,
	})
	table.insert(keepOut, Geography.circle(REGION, spring[1], spring[2], KEEP_OUT_RADIUS))
end

local prizeX, prizeZ = Geography.place(REGION, 860, 0)
table.insert(keepOut, Geography.circle(REGION, 860, 0, KEEP_OUT_RADIUS))

local site: Types.Site = {
	region = REGION,
	hazards = hazards,
	features = {},
	prize = { relicId = "R008", x = prizeX, y = 1, z = prizeZ, hold = 3 },
	keepOut = keepOut,
}

return site
