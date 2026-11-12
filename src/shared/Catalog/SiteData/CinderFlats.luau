--!strict
local Geography = require("../../Rules/Geography")
local Types = require("../../Types")
local Make = require("./Make")

local REGION: Types.RegionId = "CinderFlats"
local VENT_DAMAGE = 35
local LAVA_DPS = 30
local BASALT_TOP = 0.6

local function vent(id: string, shape: Types.Shape, cycle: Types.Cycle): Types.Hazard
	return {
		id = id,
		region = REGION,
		name = "Vent",
		look = "vent",
		shape = shape,
		cycle = cycle,
		damage = VENT_DAMAGE,
	}
end

local function lava(id: string, shape: Types.Shape, holes: { Types.Shape }?): Types.Hazard
	return {
		id = id,
		region = REGION,
		name = "Lava",
		look = "lava",
		shape = shape,
		holes = holes,
		dps = LAVA_DPS,
	}
end

local hazards: { Types.Hazard } = {}

-- A five by five grid of vents; vent 5m + n + 1 is row m, column n, and the grid erupts in a
-- slow diagonal wave.
for m = 0, 4 do
	for n = 0, 4 do
		table.insert(
			hazards,
			vent(
				`CinderVent{5 * m + n + 1}`,
				Geography.circle(REGION, 440 + 40 * m, -80 + 40 * n, 15),
				{ period = 6, warn = 1.5, active = 1, offset = ((m + 2 * n) % 5) * 1.2 }
			)
		)
	end
end

-- Lava along both flanks of the vent field.
table.insert(hazards, lava("CinderFlank1", Geography.rect(REGION, 440, 620, -190, -110), nil))
table.insert(hazards, lava("CinderFlank2", Geography.rect(REGION, 440, 620, 110, 190), nil))

local pools = {
	{ 340, -120, 22 },
	{ 350, 90, 20 },
	{ 680, -190, 26 },
	{ 700, 200, 24 },
}
for i, pool in pools do
	table.insert(
		hazards,
		lava(`CinderPool{i}`, Geography.circle(REGION, pool[1], pool[2], pool[3]), nil)
	)
end

-- The lake round the prize islet, crossed by a causeway.
table.insert(
	hazards,
	lava("CinderLake", Geography.circle(REGION, 760, 0, 110), {
		Geography.circle(REGION, 760, 0, 32),
		Geography.rect(REGION, 650, 730, -10, 10),
	})
)

-- Four vents on the causeway, firing one after another toward the islet.
for i = 1, 4 do
	table.insert(
		hazards,
		vent(
			`CinderCausewayVent{i}`,
			Geography.circle(REGION, 640 + 20 * i, 0, 11),
			{ period = 4.8, warn = 1.2, active = 0.8, offset = (i - 1) * 1.2 }
		)
	)
end

table.insert(
	hazards,
	vent(
		"CinderPrizeVent",
		Geography.circle(REGION, 760, 0, 12),
		{ period = 5, warn = 1.5, active = 1, offset = 0 }
	)
)

local features: { Types.Feature } = {
	Make.block(REGION, 650, 730, -10, 10, 0, BASALT_TOP, "basalt", true),
	Make.disc(REGION, 760, 0, 32, 0, BASALT_TOP, "basalt", true),
}

local prizeX, prizeZ = Geography.place(REGION, 760, 0)

local site: Types.Site = {
	region = REGION,
	hazards = hazards,
	features = features,
	prize = { relicId = "R011", x = prizeX, y = 1.6, z = prizeZ, hold = 3 },
	keepOut = {
		Geography.rect(REGION, 420, 640, -200, 200),
		Geography.circle(REGION, 760, 0, 120),
	},
}

return site
