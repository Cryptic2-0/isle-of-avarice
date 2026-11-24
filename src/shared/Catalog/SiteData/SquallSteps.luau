--!strict
local Geography = require("../../Rules/Geography")
local Types = require("../../Types")
local Make = require("./Make")

local REGION: Types.RegionId = "SquallSteps"
local BEARING = 60
local PILLARS = 18
local PILLAR_SIZE = 14
local PILLAR_SPACING = 19
local FIRST_PILLAR_ALONG = 480
local RISE = 3
local GUST_SPEED = 11

export type Pillar = { along: number, across: number, top: number }
export type SquallStepsSite = Types.Site & { pillars: { Pillar } }

local pillars: { Pillar } = {}
local features: { Types.Feature } = {}
for k = 1, PILLARS do
	local along = FIRST_PILLAR_ALONG + PILLAR_SPACING * (k - 1)
	local across = if k % 2 == 1 then 6 else -6
	local half = PILLAR_SIZE / 2
	table.insert(pillars, { along = along, across = across, top = RISE * k })
	table.insert(
		features,
		Make.block(
			REGION,
			along - half,
			along + half,
			across - half,
			across + half,
			0,
			RISE * k,
			"pillar",
			true
		)
	)
end
-- The summit, one rise above the last pillar.
table.insert(features, Make.block(REGION, 815, 875, -30, 30, 0, 57, "pillar", true))

-- The world velocity of a gust blowing along and across the region's bearing.
local function push(along: number, across: number): { x: number, z: number }
	local x, z = Geography.fromFrame(BEARING, along, across)
	return { x = x * GUST_SPEED, z = z * GUST_SPEED }
end

local function gust(
	n: number,
	a1: number,
	a2: number,
	c1: number,
	c2: number,
	pushing: { x: number, z: number },
	offset: number,
	markerY: number?
): Types.Hazard
	return {
		id = `SquallGust{n}`,
		region = REGION,
		name = "Gust",
		look = "gust",
		shape = Geography.rect(REGION, a1, a2, c1, c2),
		cycle = { period = 7, warn = 1.5, active = 2, offset = offset },
		push = pushing,
		markerY = markerY,
	}
end

local hazards: { Types.Hazard } = {
	gust(1, 530, 600, -40, 40, push(0, 1), 0, nil),
	gust(2, 625, 695, -40, 40, push(0, -1), 2.3, nil),
	gust(3, 720, 790, -40, 40, push(0, 1), 4.6, nil),
	gust(4, 815, 875, -30, 30, push(1, 0), 1.2, 57.2),
}

local prizeX, prizeZ = Geography.place(REGION, 845, 0)

local site: SquallStepsSite = {
	region = REGION,
	hazards = hazards,
	features = features,
	prize = { relicId = "R007", x = prizeX, y = 58, z = prizeZ, hold = 3 },
	keepOut = { Geography.rect(REGION, 470, 880, -45, 45) },
	pillars = pillars,
}

return site
