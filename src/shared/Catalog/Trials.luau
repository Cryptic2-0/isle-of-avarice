--!strict
local Types = require("../Types")

type Trial = Types.Trial

local list: { Trial } = {
	{
		id = "tidewalk",
		name = "Tidewalk",
		warden = "Harbour Warden",
		kind = "course",
		goal = "Touch 6 markers in order.",
		seconds = 60,
		relicId = "R013",
		coin = 30,
		xp = 120,
	},
	{
		id = "gullstep_climb",
		name = "Gullstep Climb",
		warden = "Cliff Warden",
		kind = "course",
		goal = "Touch 8 markers in order.",
		seconds = 75,
		relicId = "R014",
		coin = 40,
		xp = 160,
	},
	{
		id = "salt_post",
		name = "Salt Post",
		warden = "Saltworks Warden",
		kind = "delivery",
		goal = "Carry the parcel to the Harbour Warden.",
		seconds = 70,
		relicId = "R015",
		coin = 35,
		xp = 140,
	},
	{
		id = "cull_the_pack",
		name = "Cull the Pack",
		warden = "Pack Warden",
		kind = "hunt",
		goal = "Defeat 5 Brinehounds.",
		seconds = 120,
		relicId = "R016",
		coin = 40,
		xp = 180,
		creature = "brinehound",
		count = 5,
	},
	{
		id = "shellbreaker",
		name = "Shellbreaker",
		warden = "Shell Warden",
		kind = "hunt",
		goal = "Defeat 3 Shellbacks.",
		seconds = 150,
		relicId = "R024",
		coin = 70,
		xp = 300,
		creature = "shellback",
		count = 3,
	},
	{
		id = "tallymans_duel",
		name = "The Tallyman's Duel",
		warden = "Duel Warden",
		kind = "duel",
		goal = "Defeat the Drowned Tallyman.",
		seconds = 90,
		relicId = "R025",
		coin = 80,
		xp = 350,
	},
	{
		id = "reed_run",
		name = "Reed Run",
		warden = "Reed Warden",
		kind = "course",
		goal = "Touch 6 markers in order.",
		seconds = 70,
		relicId = "R040",
		coin = 40,
		xp = 170,
	},
	{
		id = "bellows_dance",
		name = "The Bellows Dance",
		warden = "Bellows Warden",
		kind = "course",
		goal = "Touch 5 markers in order.",
		seconds = 50,
		relicId = "R042",
		coin = 90,
		xp = 400,
	},
	{
		id = "spitter_season",
		name = "Spitter Season",
		warden = "Spitter Warden",
		kind = "hunt",
		goal = "Defeat 3 Bogspitters.",
		seconds = 180,
		relicId = "R045",
		coin = 80,
		xp = 380,
		creature = "bogspitter",
		count = 3,
	},
	{
		id = "grand_tally",
		name = "The Grand Tally",
		warden = "Crown Warden",
		kind = "course",
		goal = "Touch 7 markers in order: one in every wild region, then Reckoning Rock.",
		seconds = 300,
		relicId = "R049",
		coin = 200,
		xp = 900,
	},
}

local byId: { [string]: Trial } = {}
for _, trial in list do
	byId[trial.id] = trial
end

-- The two rounds: finish every step once for a Platinum Relic.
local rounds: { Types.Round } = {
	{
		id = "wardens",
		name = "The Warden's Round",
		short = "Warden's Round",
		relicId = "R046",
		coin = 250,
		xp = 800,
		steps = {
			"tidewalk",
			"gullstep_climb",
			"salt_post",
			"cull_the_pack",
			"shellbreaker",
			"tallymans_duel",
			"reed_run",
			"bellows_dance",
			"spitter_season",
		},
	},
	{
		id = "beasts",
		name = "The Beast Tally",
		short = "Beast Tally",
		relicId = "R047",
		coin = 250,
		xp = 800,
		steps = { "brinehound", "shellback", "bogspitter", "brine_colossus", "gilded_bailiff" },
	},
}
local roundById: { [string]: Types.Round } = {}
for _, round in rounds do
	roundById[round.id] = round
end

return {
	list = list,
	byId = byId,
	rounds = rounds,
	roundById = roundById,
	quest = {
		name = "The Unpaid Debt",
		steps = { "tidewalk", "salt_post", "tallymans_duel", "colossus" },
		relicId = "R027",
		coin = 150,
		xp = 600,
	},
}
