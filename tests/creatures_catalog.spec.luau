--!strict
local T = require("./harness")
local Creatures = require("../src/shared/Catalog/Creatures")
local Relics = require("../src/shared/Catalog/Relics")

type Row = {
	id: string,
	name: string,
	health: number,
	speed: number,
	sight: number,
	xp: number,
	coin: number,
	respawn: number,
}

local rows: { Row } = {
	{
		id = "brinehound",
		name = "Brinehound",
		health = 60,
		speed = 16,
		sight = 35,
		xp = 30,
		coin = 4,
		respawn = 30,
	},
	{
		id = "shellback",
		name = "Shellback",
		health = 160,
		speed = 10,
		sight = 25,
		xp = 70,
		coin = 10,
		respawn = 45,
	},
	{
		id = "bogspitter",
		name = "Bogspitter",
		health = 90,
		speed = 12,
		sight = 40,
		xp = 60,
		coin = 8,
		respawn = 45,
	},
	{
		id = "brine_colossus",
		name = "Brine Colossus",
		health = 900,
		speed = 9,
		sight = 45,
		xp = 500,
		coin = 60,
		respawn = 600,
	},
	{
		id = "drowned_tallyman",
		name = "Drowned Tallyman",
		health = 300,
		speed = 15,
		sight = 60,
		xp = 0,
		coin = 0,
		respawn = 0,
	},
}

T.test("creature table values", function()
	T.eq(#Creatures.list, 5)
	for i, row in rows do
		local c = Creatures.list[i]
		T.eq(c.id, row.id)
		T.eq(Creatures.byId[row.id], c)
		T.eq(c.name, row.name, row.id)
		T.eq(c.health, row.health, row.id)
		T.eq(c.speed, row.speed, row.id)
		T.eq(c.sight, row.sight, row.id)
		T.eq(c.xp, row.xp, row.id)
		T.eq(c.coin, row.coin, row.id)
		T.eq(c.respawn, row.respawn, row.id)
	end
end)

T.test("creature attacks", function()
	T.eq(
		Creatures.byId.brinehound.attack,
		{ kind = "melee", name = "Bite", damage = 8, range = 5, interval = 1.4 }
	)
	T.eq(
		Creatures.byId.shellback.attack,
		{ kind = "melee", name = "Claw", damage = 14, range = 6, interval = 2 }
	)
	T.eq(
		Creatures.byId.bogspitter.attack,
		{ kind = "shot", name = "Spit", damage = 10, range = 30, interval = 2.5 }
	)
	T.eq(
		Creatures.byId.brine_colossus.attack,
		{ kind = "slam", name = "Slam", damage = 25, range = 10, interval = 4 }
	)
	T.eq(
		Creatures.byId.drowned_tallyman.attack,
		{ kind = "melee", name = "Strike", damage = 12, range = 7, interval = 1.2 }
	)
end)

T.test("creature extras and drops", function()
	T.eq(Creatures.byId.bogspitter.keepAway, 15)
	T.eq(Creatures.byId.brinehound.keepAway, nil)
	T.eq(Creatures.byId.drowned_tallyman.lunge, { distance = 12, damage = 18, interval = 8 })
	T.eq(Creatures.byId.brinehound.lunge, nil)
	T.eq(Creatures.byId.brinehound.drops, { { relicId = "R019", chance = 0.02 } })
	T.eq(Creatures.byId.shellback.drops, { { relicId = "R020", chance = 0.05 } })
	T.eq(Creatures.byId.bogspitter.drops, { { relicId = "R021", chance = 0.05 } })
	T.eq(
		Creatures.byId.brine_colossus.drops,
		{ { relicId = "R022", chance = 1 }, { relicId = "R023", chance = 0.2 } }
	)
	T.eq(Creatures.byId.drowned_tallyman.drops, {})
end)

T.test("every drop names a known Relic and ids match keys", function()
	local n = 0
	for id, c in Creatures.byId do
		n += 1
		T.eq(c.id, id)
		T.truthy(c.height > 0, id .. " height")
		for _, channel in { c.color.r, c.color.g, c.color.b } do
			T.truthy(channel >= 0 and channel <= 255, id .. " color")
		end
		for _, drop in c.drops do
			T.truthy(Relics.byId[drop.relicId] ~= nil, id .. " drop " .. drop.relicId)
			T.truthy(drop.chance > 0 and drop.chance <= 1, id .. " chance")
		end
	end
	T.eq(n, #Creatures.list)
end)
