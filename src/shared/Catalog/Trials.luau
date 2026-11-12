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
}

local byId: { [string]: Trial } = {}
for _, trial in list do
	byId[trial.id] = trial
end

return {
	list = list,
	byId = byId,
	quest = {
		name = "The Unpaid Debt",
		steps = { "tidewalk", "salt_post", "tallymans_duel", "colossus" },
		relicId = "R027",
		coin = 150,
		xp = 600,
	},
}
