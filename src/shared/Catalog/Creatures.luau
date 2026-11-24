--!strict
local Types = require("../Types")

type CreatureKind = Types.CreatureKind

local list: { CreatureKind } = {
	{
		id = "brinehound",
		name = "Brinehound",
		health = 60,
		speed = 16,
		sight = 35,
		attack = { kind = "melee", name = "Bite", damage = 8, range = 5, interval = 1.4 },
		xp = 30,
		coin = 4,
		respawn = 30,
		drops = { { relicId = "R019", chance = 0.02 }, { relicId = "R035", chance = 0.06 } },
		height = 3,
		color = { r = 70, g = 90, b = 100 },
	},
	{
		id = "shellback",
		name = "Shellback",
		health = 160,
		speed = 10,
		sight = 25,
		attack = { kind = "melee", name = "Claw", damage = 14, range = 6, interval = 2 },
		xp = 70,
		coin = 10,
		respawn = 45,
		drops = { { relicId = "R020", chance = 0.05 }, { relicId = "R036", chance = 0.08 } },
		height = 4,
		color = { r = 150, g = 120, b = 60 },
	},
	{
		id = "bogspitter",
		name = "Bogspitter",
		health = 90,
		speed = 12,
		sight = 40,
		attack = { kind = "shot", name = "Spit", damage = 10, range = 30, interval = 2.5 },
		keepAway = 15,
		xp = 60,
		coin = 8,
		respawn = 45,
		drops = { { relicId = "R021", chance = 0.05 }, { relicId = "R037", chance = 0.08 } },
		height = 4,
		color = { r = 90, g = 120, b = 50 },
	},
	{
		id = "brine_colossus",
		name = "Brine Colossus",
		health = 900,
		speed = 9,
		sight = 45,
		attack = { kind = "slam", name = "Slam", damage = 25, range = 10, interval = 4 },
		xp = 500,
		coin = 60,
		respawn = 600,
		drops = {
			{ relicId = "R022", chance = 1 },
			{ relicId = "R023", chance = 0.2 },
			{ relicId = "R043", chance = 0.15 },
		},
		height = 14,
		color = { r = 40, g = 70, b = 90 },
	},
	{
		id = "drowned_tallyman",
		name = "Drowned Tallyman",
		health = 300,
		speed = 15,
		sight = 60,
		attack = { kind = "melee", name = "Strike", damage = 12, range = 7, interval = 1.2 },
		lunge = { distance = 12, damage = 18, interval = 8 },
		xp = 0,
		coin = 0,
		respawn = 0,
		drops = {},
		height = 6,
		color = { r = 120, g = 150, b = 140 },
	},
	{
		id = "gilded_bailiff",
		name = "Gilded Bailiff",
		health = 2400,
		speed = 12,
		sight = 50,
		attack = { kind = "slam", name = "Gavel Slam", damage = 30, range = 12, interval = 3.5 },
		lunge = { distance = 20, damage = 25, interval = 9 },
		xp = 900,
		coin = 120,
		respawn = 1200,
		drops = { { relicId = "R048", chance = 1 }, { relicId = "R041", chance = 0.3 } },
		height = 14,
		color = { r = 215, g = 170, b = 60 },
	},
}

local byId: { [string]: CreatureKind } = {}
for _, creature in list do
	byId[creature.id] = creature
end

return {
	list = list,
	byId = byId,
}
