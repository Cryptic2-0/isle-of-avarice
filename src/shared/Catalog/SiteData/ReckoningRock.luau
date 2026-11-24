--!strict
local Geography = require("../../Rules/Geography")
local Types = require("../../Types")

-- The Rock has no bearing of its own. It lies due south of the island centre, so it is measured
-- in the Fen's frame: along is world z, across is minus world x, and the Rock's centre is
-- (1240, 0).
local FRAME = "DrownedFen"

local site: Types.Site = {
	region = "ReckoningRock",
	hazards = {
		{
			id = "RockTide",
			region = "ReckoningRock",
			name = "High tide",
			look = "tide",
			shape = Geography.rect(FRAME, 940, 1160, -20, 20),
			cycle = { period = 120, warn = 15, active = 35, offset = 0 },
			dps = 40,
		},
	},
	features = {},
	-- World coordinates, written out so the Rock's x is exactly 0.
	prize = { relicId = "R010", x = 0, y = 1, z = 1240, hold = 3 },
	keepOut = { Geography.circle(FRAME, 1240, 0, 30) },
}

return site
