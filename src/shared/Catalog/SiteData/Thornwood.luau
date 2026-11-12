--!strict
local Geography = require("../../Rules/Geography")
local Types = require("../../Types")
local Make = require("./Make")

export type ThornwoodSite = Types.Site & {
	MAZE: { string },
	cellCentre: (number, number) -> (number, number),
}

local REGION: Types.RegionId = "Thornwood"
local FIRST_ROW_ALONG = 490
local SQUARE = 20
local HALF = SQUARE / 2
local HEDGE_HEIGHT = 14

-- Nearest row first. "#" hedge, "b" briar gap, "P" the prize square, "." open ground.
local MAZE = {
	"#######.#########",
	"#...#...#...#...#",
	"#.#.#.#b#.#.#.#.#",
	"#.#.#.#...#...#.#",
	"#.###.#.#######.#",
	"#.#...#.......#.#",
	"#.#.#########.#.#",
	"..#...b.....#.#.#",
	"#.###.#.P.#.#.b.#",
	"#.....#.....#.#..",
	"#.#####.#.#.#.#.#",
	"#.....#.#.#.#.#.#",
	"#####.b.#.###.#.#",
	"#...#.#.#.....b.#",
	"#.###.###b#####.#",
	"#...............#",
	"#################",
}

-- Square (r, c), both from 1, as the along and across of its centre in the region frame.
local function cellCentre(r: number, c: number): (number, number)
	return FIRST_ROW_ALONG + SQUARE * (r - 1), SQUARE * (c - 9)
end

local function squareShape(r: number, c: number): Types.Shape
	local along, across = cellCentre(r, c)
	return Geography.rect(REGION, along - HALF, along + HALF, across - HALF, across + HALF)
end

local function briars(id: string, shape: Types.Shape): Types.Hazard
	return {
		id = id,
		region = REGION,
		name = "Briars",
		look = "briar",
		shape = shape,
		dps = 12,
		slow = 0.6,
	}
end

local features: { Types.Feature } = {}
local hazards: { Types.Hazard } = {}
local prize: Types.SiteCache? = nil

for r, row in MAZE do
	local along = cellCentre(r, 1)
	-- Each maximal run of hedge is one block. The column after the row's end closes a last run.
	local runStart: number? = nil
	for c = 1, #row + 1 do
		local char = string.sub(row, c, c)
		if char == "#" and runStart == nil then
			runStart = c
		elseif char ~= "#" and runStart ~= nil then
			local _, firstAcross = cellCentre(r, runStart)
			local _, lastAcross = cellCentre(r, c - 1)
			table.insert(
				features,
				Make.block(
					REGION,
					along - HALF,
					along + HALF,
					firstAcross - HALF,
					lastAcross + HALF,
					0,
					HEDGE_HEIGHT,
					"hedge",
					true
				)
			)
			runStart = nil
		end
		if char == "b" then
			table.insert(hazards, briars(`ThornBriar{#hazards + 1}`, squareShape(r, c)))
		elseif char == "P" then
			local x, z = Geography.place(REGION, cellCentre(r, c))
			prize = { relicId = "R009", x = x, y = 1, z = z, hold = 3 }
		end
	end
end

-- Briars growing in the open, outside the maze: along, across.
local thickets = {
	{ 350, -100 },
	{ 380, 110 },
	{ 420, -150 },
	{ 440, 60 },
	{ 455, -60 },
	{ 415, -35 },
}
for i, at in thickets do
	table.insert(hazards, briars(`ThornThicket{i}`, Geography.circle(REGION, at[1], at[2], 14)))
end

local site: ThornwoodSite = {
	region = REGION,
	hazards = hazards,
	features = features,
	prize = prize,
	keepOut = { Geography.rect(REGION, 480, 820, -170, 170) },
	MAZE = MAZE,
	cellCentre = cellCentre,
}

return site
