--!strict
local T = require("./harness")
local Creatures = require("../src/shared/Catalog/Creatures")
local Relics = require("../src/shared/Catalog/Relics")
local Trials = require("../src/shared/Catalog/Trials")

local rows = {
	{
		"tidewalk",
		"Tidewalk",
		"Harbour Warden",
		"course",
		"Touch 6 markers in order.",
		60,
		"R013",
		30,
		120,
	},
	{
		"gullstep_climb",
		"Gullstep Climb",
		"Cliff Warden",
		"course",
		"Touch 8 markers in order.",
		75,
		"R014",
		40,
		160,
	},
	{
		"salt_post",
		"Salt Post",
		"Saltworks Warden",
		"delivery",
		"Carry the parcel to the Harbour Warden.",
		70,
		"R015",
		35,
		140,
	},
	{
		"cull_the_pack",
		"Cull the Pack",
		"Pack Warden",
		"hunt",
		"Defeat 5 Brinehounds.",
		120,
		"R016",
		40,
		180,
	},
	{
		"shellbreaker",
		"Shellbreaker",
		"Shell Warden",
		"hunt",
		"Defeat 3 Shellbacks.",
		150,
		"R024",
		70,
		300,
	},
	{
		"tallymans_duel",
		"The Tallyman's Duel",
		"Duel Warden",
		"duel",
		"Defeat the Drowned Tallyman.",
		90,
		"R025",
		80,
		350,
	},
	{
		"reed_run",
		"Reed Run",
		"Reed Warden",
		"course",
		"Touch 6 markers in order.",
		70,
		"R040",
		40,
		170,
	},
	{
		"bellows_dance",
		"The Bellows Dance",
		"Bellows Warden",
		"course",
		"Touch 5 markers in order.",
		50,
		"R042",
		90,
		400,
	},
	{
		"spitter_season",
		"Spitter Season",
		"Spitter Warden",
		"hunt",
		"Defeat 3 Bogspitters.",
		180,
		"R045",
		80,
		380,
	},
	{
		"grand_tally",
		"The Grand Tally",
		"Crown Warden",
		"course",
		"Touch 7 markers in order: one in every wild region, then Reckoning Rock.",
		300,
		"R049",
		200,
		900,
	},
}

T.test("trial table values", function()
	T.eq(#Trials.list, #rows)
	for i, row in rows do
		local t = Trials.list[i]
		T.eq(t.id, row[1])
		T.eq(Trials.byId[t.id], t)
		T.eq(t.name, row[2], t.id)
		T.eq(t.warden, row[3], t.id)
		T.eq(t.kind, row[4], t.id)
		T.eq(t.goal, row[5], t.id)
		T.eq(t.seconds, row[6], t.id)
		T.eq(t.relicId, row[7], t.id)
		T.eq(t.coin, row[8], t.id)
		T.eq(t.xp, row[9], t.id)
	end
end)

T.test("hunt trials name a creature and count", function()
	T.eq(Trials.byId.cull_the_pack.creature, "brinehound")
	T.eq(Trials.byId.cull_the_pack.count, 5)
	T.eq(Trials.byId.shellbreaker.creature, "shellback")
	T.eq(Trials.byId.shellbreaker.count, 3)
	T.eq(
		{ Trials.byId.spitter_season.creature, Trials.byId.spitter_season.count },
		{ "bogspitter", 3 }
	)
	for _, t in Trials.list do
		if t.kind == "hunt" then
			T.truthy(t.creature ~= nil and Creatures.byId[t.creature] ~= nil, t.id .. " creature")
			T.truthy(t.count ~= nil and t.count > 0, t.id .. " count")
		else
			T.eq(t.creature, nil, t.id)
			T.eq(t.count, nil, t.id)
		end
	end
end)

T.test("every trial relic is known", function()
	for _, t in Trials.list do
		T.truthy(Relics.byId[t.relicId] ~= nil, t.id .. " relic")
	end
	T.truthy(Relics.byId[Trials.quest.relicId] ~= nil, "quest relic")
end)

T.test("the quest", function()
	T.eq(Trials.quest.name, "The Unpaid Debt")
	T.eq(Trials.quest.steps, { "tidewalk", "salt_post", "tallymans_duel", "colossus" })
	T.eq(Trials.quest.relicId, "R027")
	T.eq(Trials.quest.coin, 150)
	T.eq(Trials.quest.xp, 600)
end)

T.test("the two rounds", function()
	T.eq(#Trials.rounds, 2)
	local w, b = Trials.roundById.wardens, Trials.roundById.beasts
	T.eq(
		{ w.name, w.short, w.relicId, w.coin, w.xp },
		{ "The Warden's Round", "Warden's Round", "R046", 250, 800 }
	)
	T.eq(
		{ b.name, b.short, b.relicId, b.coin, b.xp },
		{ "The Beast Tally", "Beast Tally", "R047", 250, 800 }
	)
	T.eq(w.steps, {
		"tidewalk",
		"gullstep_climb",
		"salt_post",
		"cull_the_pack",
		"shellbreaker",
		"tallymans_duel",
		"reed_run",
		"bellows_dance",
		"spitter_season",
	})
	T.eq(b.steps, { "brinehound", "shellback", "bogspitter", "brine_colossus", "gilded_bailiff" })
	for _, step in w.steps do
		T.truthy(Trials.byId[step] ~= nil and step ~= "grand_tally", step)
	end
	for _, step in b.steps do
		T.truthy(Creatures.byId[step] ~= nil, step)
	end
	T.eq(Trials.roundById.wardens, Trials.rounds[1])
end)
