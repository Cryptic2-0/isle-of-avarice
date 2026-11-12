--!strict
local Types = require("../Types")

type Region = Types.Region
type RegionId = Types.RegionId

local list: { Region } = {
	{
		id = "Tallyport",
		name = "Tallyport",
		hint = "Safe ground. No fighting here.",
		ground = "grass",
		fog = { r = 200, g = 215, b = 230, start = 200, finish = 2500 },
	},
	{
		id = "CountingFields",
		name = "Counting Fields",
		hint = "Quiet fields. Nothing here will hurt you.",
		ground = "grass",
		fog = { r = 200, g = 215, b = 230, start = 200, finish = 2500 },
	},
	{
		id = "Thornwood",
		name = "Thornwood",
		hint = "A hedge maze. Briars are a shortcut that costs health.",
		bearing = 0,
		ground = "thorngrass",
		fog = { r = 60, g = 90, b = 60, start = 80, finish = 900 },
	},
	{
		id = "SquallSteps",
		name = "Squall Steps",
		hint = "Climb the pillars. Brace when the wind lanes glow.",
		bearing = 60,
		ground = "slate",
		fog = { r = 210, g = 225, b = 240, start = 300, finish = 3000 },
	},
	{
		id = "CinderFlats",
		name = "Cinder Flats",
		hint = "Vents glow before they erupt. Lava burns fast.",
		bearing = 120,
		ground = "ash",
		fog = { r = 120, g = 50, b = 30, start = 120, finish = 1200 },
	},
	{
		id = "DrownedFen",
		name = "Drowned Fen",
		hint = "Stay on the boardwalk. The bog slows and drains you.",
		bearing = 180,
		ground = "mud",
		fog = { r = 110, g = 125, b = 110, start = 30, finish = 450 },
	},
	{
		id = "ReckoningRock",
		name = "Reckoning Rock",
		hint = "The causeway floods at high tide. The Rock is safe.",
		ground = "shale",
		fog = { r = 150, g = 170, b = 190, start = 100, finish = 1500 },
	},
	{
		id = "HushGardens",
		name = "Hush Gardens",
		hint = "The blight drains you. Springs heal.",
		bearing = 240,
		ground = "palegrass",
		fog = { r = 170, g = 150, b = 190, start = 100, finish = 1000 },
	},
	{
		id = "BastionReach",
		name = "Bastion Reach",
		hint = "Rocks fall where the ground glows. Shelter under the roofs.",
		bearing = 300,
		ground = "gravel",
		fog = { r = 150, g = 150, b = 160, start = 150, finish = 1600 },
	},
}

local byId: { [string]: Region } = {}
for _, region in list do
	byId[region.id] = region
end

-- The six regions with a bearing, in bearing order (0, 60, ... 300).
local wild: { RegionId } = {
	"Thornwood",
	"SquallSteps",
	"CinderFlats",
	"DrownedFen",
	"HushGardens",
	"BastionReach",
}

return {
	list = list,
	byId = byId,
	wild = wild,
}
