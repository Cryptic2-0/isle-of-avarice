--!strict
local T = require("./harness")
local Abilities = require("../src/shared/Catalog/Abilities")
local Casting = require("../src/shared/Rules/Casting")
local Combat = require("../src/shared/Rules/Combat")
local Types = require("../src/shared/Types")

type PathProgress = Types.PathProgress

local ab = Abilities.byId

local function progress(loadout: { string }): PathProgress
	return {
		calling = "Fang",
		xp = { Fang = 4500, Gale = 0, Ember = 0, Mire = 0, Mend = 0, Bulwark = 0 },
		loadout = loadout,
		callingChanges = 0,
		callingChangedAt = 0,
	}
end

local fang = progress({ "lunge", "", "rending_flurry", "" })

local me: Combat.Fighter =
	{ id = 1, position = { x = 0, y = 0, z = 0 }, look = { x = 0, y = 0, z = -1 } }

local function at(id: number, x: number, y: number, z: number): Combat.Fighter
	return { id = id, position = { x = x, y = y, z = z }, look = { x = 0, y = 0, z = 1 } }
end

T.test("canCast accepts a ready unlocked slot", function()
	local s0 = Casting.new()
	T.eq({ Casting.canCast(s0, fang, 1, 0, false) }, { "lunge", "OK" })
	T.eq({ Casting.canCast(s0, fang, 2, 0, false) }, { nil, "NO_ABILITY" })
end)

T.test("canCast rejects a slot that is not an integer 1 to 4", function()
	local s0 = Casting.new()
	for _, bad in { 0, 5, 1.5, 0 / 0, math.huge, -math.huge, "1", {} } do
		T.eq({ Casting.canCast(s0, fang, bad, 0, false) }, { nil, "BAD_REQUEST" })
	end
	local id, code = Casting.canCast(s0, fang, nil, 0, false)
	T.eq(id, nil)
	T.eq(code, "BAD_REQUEST")
end)

T.test("canCast enforces cooldown and the global gap", function()
	local s0 = Casting.new()
	local s1 = Casting.commit(s0, "lunge", 0)
	T.eq(select(2, Casting.canCast(s1, fang, 1, 5.9, false)), "ON_COOLDOWN")
	T.eq(select(2, Casting.canCast(s1, fang, 1, 6, false)), "OK")
	T.eq(select(2, Casting.canCast(s1, fang, 3, 0.29, false)), "ON_COOLDOWN")
	T.eq(select(2, Casting.canCast(s1, fang, 3, 0.3, false)), "OK")
end)

T.test("canCast blocks only dashes while rooted", function()
	local s0 = Casting.new()
	T.eq(select(2, Casting.canCast(s0, fang, 1, 0, true)), "ROOTED")
	T.eq(select(2, Casting.canCast(s0, fang, 3, 0, true)), "OK")
end)

T.test("canCast rejects a locked ability in the loadout", function()
	local tampered = progress({ "undertow", "", "", "" })
	T.eq({ Casting.canCast(Casting.new(), tampered, 1, 0, false) }, { nil, "NOT_UNLOCKED" })
end)

T.test("canCast checks cooldown before rooted", function()
	local s1 = Casting.commit(Casting.new(), "lunge", 0)
	T.eq(select(2, Casting.canCast(s1, fang, 1, 1, true)), "ON_COOLDOWN")
end)

T.test("canCast and commit never mutate the state passed in", function()
	local s0 = Casting.new()
	T.eq(s0.lastCast, -math.huge)
	local s1 = Casting.commit(s0, "lunge", 10)
	T.eq(s0.lastCast, -math.huge)
	T.eq(next(s0.cooldowns), nil)
	T.eq(s1.cooldowns, { lunge = 16 })
	T.eq(s1.lastCast, 10)
	local s2 = Casting.commit(s1, "rending_flurry", 11)
	T.eq(s1.cooldowns, { lunge = 16 })
	T.eq(s2.cooldowns, { lunge = 16, rending_flurry = 19 })
	Casting.canCast(s2, fang, 1, 12, false)
	T.eq(s2.cooldowns, { lunge = 16, rending_flurry = 19 })
	T.eq(s2.lastCast, 11)
end)

T.test("plan melee and shot", function()
	T.eq(
		Casting.plan(ab.gust_blade, me, { at(2, 0, 0, -20) }).hits,
		{ { targetId = 2, damage = 18 } }
	)
	local low, high = at(2, 0, 0, -5), at(3, 0, 0, -5)
	low.health = 35
	high.health = 36
	T.eq(Casting.plan(ab.final_toll, me, { low }).hits, { { targetId = 2, damage = 40 } })
	T.eq(Casting.plan(ab.final_toll, me, { high }).hits, { { targetId = 3, damage = 12 } })
	T.eq(#Casting.plan(ab.scattershot, me, { at(2, 0, 0, -10) }).hits, 3)
	T.eq(Casting.plan(ab.undertow, me, { at(2, 0, 0, -20) }).pullTo, { x = 0, y = 0, z = -4 })
	T.eq(
		Casting.plan(ab.shield_bash, me, { at(2, 0, 0, -5) }).knockbackTo,
		{ x = 0, y = 0, z = -15 }
	)
	local flurry = Casting.plan(ab.rending_flurry, me, { at(2, 0, 0, -5) })
	T.eq(
		{ flurry.hits, flurry.waves, flurry.interval },
		{ { { targetId = 2, damage = 10 } }, 3, 0.25 }
	)
	T.eq(
		Casting.plan(ab.gust_blade, me, { at(2, 0, 0, -10), at(7, 0, 0, -20) }, 7).hits[1].targetId,
		7
	)
end)

T.test("plan single hit defaults", function()
	local p = Casting.plan(ab.gust_blade, me, { at(2, 0, 0, -20) })
	T.eq({ p.waves, p.interval }, { 1, 0 })
	T.eq(p.moveTo, nil)
	T.eq(p.pullTo, nil)
	T.eq(p.knockbackTo, nil)
	T.eq(p.zone, nil)
	T.eq(Casting.plan(ab.gust_blade, me, {}).hits, {})
end)

T.test("plan dash, zone, burst, self", function()
	local lunge = Casting.plan(ab.lunge, me, { at(2, 0, 0, -6) })
	T.eq(
		{ lunge.hits, lunge.moveTo },
		{ { { targetId = 2, damage = 22 } }, { x = 0, y = 0, z = -12 } }
	)
	T.eq(Casting.plan(ab.slipstream, me, {}).moveTo, { x = 0, y = 0, z = -20 })
	T.eq(Casting.plan(ab.slipstream, me, {}).hits, {})
	local ash = Casting.plan(ab.ashfield, me, {})
	T.eq(ash.zone, { center = { x = 0, y = 0, z = -25 }, radius = 8, duration = 5, dps = 7 })
	T.eq((ash.zone :: any).slow, nil)
	T.eq(ash.hits, {})
	T.eq(
		Casting.plan(ab.sinking_field, me, {}).zone,
		{ center = { x = 0, y = 0, z = 0 }, radius = 10, duration = 4, dps = 3, slow = 0.5 }
	)
	T.eq(
		#Casting.plan(ab.challenge, me, { at(2, 5, 0, 0), at(3, 0, 0, 11), at(4, 0, 0, 13) }).hits,
		2
	)
	for _, id in { "afterimage", "ward", "renewal", "rebuke" } do
		T.eq(Casting.plan(ab[id], me, { at(2, 0, 0, -3) }).hits, {})
	end
end)
