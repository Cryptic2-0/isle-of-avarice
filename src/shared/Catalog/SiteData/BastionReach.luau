--!strict
local Geography = require("../../Rules/Geography")
local Types = require("../../Types")
local Make = require("./Make")

local REGION: Types.RegionId = "BastionReach"
local WALL_HEIGHT = 24
local ROOF_BOTTOM = 12
local ROOF_TOP = 13.5
local POST_RADIUS = 1.5

-- The three yards, nearest first: the along of the curtain wall that opens the yard, and the
-- across of the gate in it.
local CURTAIN_ALONGS = { 520, 640, 760 }
local GATES = { -120, 120, -120 }

local features: { Types.Feature } = {}

local function wall(a1: number, a2: number, c1: number, c2: number)
	table.insert(features, Make.block(REGION, a1, a2, c1, c2, 0, WALL_HEIGHT, "wall", true))
end

-- A curtain wall across each yard's mouth, with a 20-stud gate centred on the across g.
for i, a in CURTAIN_ALONGS do
	local gate = GATES[i]
	wall(a - 4, a + 4, -200, gate - 10)
	wall(a - 4, a + 4, gate + 10, 200)
end
wall(516, 884, -204, -196)
wall(516, 884, 196, 204)
wall(876, 884, -200, 200)

-- One shelter per yard: a roof on two posts, in line with the prize.
for _, a in CURTAIN_ALONGS do
	table.insert(
		features,
		Make.block(REGION, a + 12, a + 108, -16, 16, ROOF_BOTTOM, ROOF_TOP, "roof", true)
	)
	table.insert(features, Make.disc(REGION, a + 14, 0, POST_RADIUS, 0, ROOF_BOTTOM, "wall", true))
	table.insert(features, Make.disc(REGION, a + 106, 0, POST_RADIUS, 0, ROOF_BOTTOM, "wall", true))
end

-- Three rows of rocks in each yard. The middle column (n = 5) is left bare: that is the shelter
-- line, and the way to the prize.
local hazards: { Types.Hazard } = {}
for yard, a in CURTAIN_ALONGS do
	local damage = if yard == 3 then 35 else 30
	for row = 0, 2 do
		for n = 0, 10 do
			if n ~= 5 then
				local cycle: Types.Cycle = if yard == 3
					then { period = 4.5, warn = 1.5, active = 0.6, offset = ((n + row) % 3) * 1.5 }
					else { period = 6, warn = 2, active = 0.6, offset = ((n + row) % 4) * 1.5 }
				table.insert(hazards, {
					id = `BastionRock{yard}_{row}_{n}`,
					region = REGION,
					name = "Rockfall",
					look = "rockfall",
					shape = Geography.circle(REGION, a + 24 + 36 * row, -180 + 36 * n, 18),
					cycle = cycle,
					damage = damage,
				})
			end
		end
	end
end

local prizeX, prizeZ = Geography.place(REGION, 820, 0)

local site: Types.Site = {
	region = REGION,
	hazards = hazards,
	features = features,
	prize = { relicId = "R012", x = prizeX, y = 1, z = prizeZ, hold = 4 },
	keepOut = { Geography.rect(REGION, 510, 890, -210, 210) },
}

return site
