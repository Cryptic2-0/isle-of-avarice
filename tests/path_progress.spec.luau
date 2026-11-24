--!strict
local T = require("./harness")
local P = require("../src/shared/Rules/PathProgress")
local Types = require("../src/shared/Types")

type PathProgress = Types.PathProgress

local function progress(
	calling: string,
	xp: { [string]: number },
	loadout: { string }?
): PathProgress
	local full = { Fang = 0, Gale = 0, Ember = 0, Mire = 0, Mend = 0, Bulwark = 0 }
	for k, v in xp do
		full[k] = v
	end
	return {
		calling = calling,
		xp = full,
		loadout = loadout or { "", "", "", "" },
		callingChanges = 0,
		callingChangedAt = 0,
	}
end

T.test("PathProgress distance and learning rates", function()
	T.eq({
		P.distance("Fang", "Fang"),
		P.distance("Fang", "Gale"),
		P.distance("Fang", "Bulwark"),
		P.distance("Fang", "Ember"),
		P.distance("Fang", "Mend"),
		P.distance("Fang", "Mire"),
	}, { 0, 1, 1, 2, 2, 3 })
	T.eq(P.distance("Gale", "Mend"), 3)
	T.eq(P.distance("Ember", "Bulwark"), 3)
	T.eq({
		P.learningRate("Fang", "Fang"),
		P.learningRate("Fang", "Gale"),
		P.learningRate("Fang", "Ember"),
		P.learningRate("Fang", "Mire"),
	}, { 1, 0.8, 0.6, 0.4 })
	T.eq(P.learningRate("", "Fang"), 0)
end)

T.test("PathProgress level curve", function()
	T.eq({
		P.totalXpForLevel(1),
		P.totalXpForLevel(3),
		P.totalXpForLevel(10),
		P.totalXpForLevel(18),
		P.totalXpForLevel(20),
	}, { 0, 300, 4500, 15300, 19000 })
	T.eq(P.maxXp(), 19000)
	T.eq({
		P.levelForXp(0),
		P.levelForXp(299),
		P.levelForXp(300),
		P.levelForXp(4499),
		P.levelForXp(4500),
		P.levelForXp(19000),
		P.levelForXp(99999),
	}, { 1, 2, 3, 9, 10, 20, 20 })
	T.eq({ P.levelForXp(-5), P.levelForXp(0 / 0) }, { 1, 1 })
	T.eq(P.level(progress("Fang", { Fang = 4500 }), "Fang"), 10)
	T.eq(P.level(progress("Fang", { Fang = 4500 }), "Nen"), 1)
end)

T.test("PathProgress new", function()
	T.eq(P.new(), {
		calling = "",
		xp = { Fang = 0, Gale = 0, Ember = 0, Mire = 0, Mend = 0, Bulwark = 0 },
		loadout = { "", "", "", "" },
		callingChanges = 0,
		callingChangedAt = 0,
	})
end)

T.test("PathProgress chooseCalling", function()
	local p1, code1, new1 = P.chooseCalling(P.new(), "Ember")
	T.truthy(p1 ~= nil)
	local chosen = p1 :: PathProgress
	T.eq(
		{ chosen.calling, chosen.xp.Ember, code1, new1 },
		{ "Ember", 300, "CALLING_CHOSEN", { "cinder_bolt" } }
	)
	local again, againCode, againNew = P.chooseCalling(chosen, "Fang")
	T.eq(again, nil)
	T.eq({ againCode, againNew }, { "CALLING_ALREADY_SET", {} })
	for _, bad in { "Nen", "fang", 5, {} } do
		local r, code, ids = P.chooseCalling(P.new(), bad)
		T.eq(r, nil)
		T.eq({ code, ids }, { "BAD_REQUEST", {} })
	end
	local r, code, ids = P.chooseCalling(P.new(), nil)
	T.eq(r, nil)
	T.eq({ code, ids }, { "BAD_REQUEST", {} })
	-- keeps higher XP
	local rich = P.chooseCalling(progress("", { Fang = 1000 }), "Fang") :: PathProgress
	T.eq(rich.xp.Fang, 1000)
end)

T.test("PathProgress addXp", function()
	local f = P.chooseCalling(P.new(), "Fang") :: PathProgress
	T.eq(select(2, P.addXp(f, "Fang", 10)), 10)
	T.eq(select(2, P.addXp(f, "Gale", 10)), 8)
	T.eq(select(2, P.addXp(f, "Ember", 10)), 6)
	T.eq(select(2, P.addXp(f, "Mire", 10)), 4)
	T.eq(select(2, P.addXp(f, "Fang", 150)), 150)
	T.eq(select(2, P.addXp(f, "Mire", 150)), 60)
	local f2, gained, levels, unlockedNow = P.addXp({
		calling = "Fang",
		xp = { Fang = 4495, Gale = 0, Ember = 0, Mire = 0, Mend = 0, Bulwark = 0 },
		loadout = { "lunge", "", "", "" },
		callingChanges = 0,
		callingChangedAt = 0,
	}, "Fang", 10)
	T.eq({ f2.xp.Fang, gained, levels, unlockedNow }, { 4505, 10, 1, { "rending_flurry" } })

	-- cap
	local near = progress("Fang", { Fang = 18995 })
	local capped, capGained = P.addXp(near, "Fang", 100)
	T.eq({ capped.xp.Fang, capGained }, { 19000, 5 })
	local full, fullGained = P.addXp(capped, "Fang", 100)
	T.eq({ full.xp.Fang, fullGained }, { 19000, 0 })

	-- zero-gain cases
	for _, base in { 0 / 0, -10, math.huge } do
		local r, g, l, u = P.addXp(f, "Fang", base)
		T.eq({ r, g, l, u }, { f, 0, 0, {} })
	end
	local r1, g1 = P.addXp(f, "Nen", 10)
	T.eq({ r1, g1 }, { f, 0 })
	local r2, g2 = P.addXp(P.new(), "Fang", 10)
	T.eq({ r2, g2 }, { P.new(), 0 })

	-- not mutated
	T.eq(f, progress("Fang", { Fang = 300 }))
end)

T.test("PathProgress unlocked", function()
	T.eq(
		P.unlocked(progress("Fang", { Fang = 4500, Ember = 300 })),
		{ "lunge", "rending_flurry", "cinder_bolt" }
	)
	T.eq(P.unlocked(P.new()), {})
end)

T.test("PathProgress changeCalling", function()
	local f = P.chooseCalling(P.new(), "Fang") :: PathProgress
	local c1, cc1, cost1 = P.changeCalling(f, "Mire", 0, 1000)
	local changed = c1 :: PathProgress
	T.eq({
		changed.calling,
		cc1,
		cost1,
		changed.callingChanges,
		changed.callingChangedAt,
		changed.xp.Fang,
	}, { "Mire", "CALLING_CHANGED", 0, 1, 1000, 300 })
	local a, ac, acost = P.changeCalling(changed, "Fang", 9999, 1000 + 604799)
	T.eq(a, nil)
	T.eq({ ac, acost }, { "CALLING_COOLDOWN", 0 })
	local b, bc, bcost = P.changeCalling(changed, "Fang", 499, 1000 + 604800)
	T.eq(b, nil)
	T.eq({ bc, bcost }, { "NOT_ENOUGH_COIN", 0 })
	T.eq(select(3, P.changeCalling(changed, "Fang", 500, 1000 + 604800)), 500)
	T.eq(select(2, P.changeCalling(changed, "Mire", 9999, 1e9)), "CALLING_SAME")
	T.eq(select(2, P.changeCalling(P.new(), "Mire", 9999, 1e9)), "NO_CALLING")
	T.eq(select(2, P.changeCalling(changed, "Nen", 9999, 1e9)), "BAD_REQUEST")
	-- NaN fails safe
	T.eq(select(2, P.changeCalling(changed, "Fang", 0 / 0, 1e9)), "NOT_ENOUGH_COIN")
	T.eq(select(2, P.changeCalling(changed, "Fang", 9999, 0 / 0)), "CALLING_COOLDOWN")
	-- input not mutated
	T.eq(f.calling, "Fang")
end)

T.test("PathProgress sanitize", function()
	T.eq(P.sanitize(nil), P.new())
	T.eq(P.sanitize("junk"), P.new())
	local s = P.sanitize({
		calling = "Nen",
		xp = { Fang = -5, Gale = 0 / 0, Ember = 1e9, Mire = "x" },
		loadout = 7,
		callingChanges = "2",
		callingChangedAt = 0 / 0,
	})
	T.eq(s, {
		calling = "",
		xp = { Fang = 0, Gale = 0, Ember = 19000, Mire = 0, Mend = 0, Bulwark = 0 },
		loadout = { "", "", "", "" },
		callingChanges = 0,
		callingChangedAt = 0,
	})
	local s2 = P.sanitize({
		calling = "Fang",
		xp = { Fang = 300 },
		loadout = { "lunge", "final_toll", "lunge", "nope", "gust_blade" },
	})
	T.eq(s2.loadout, { "lunge", "", "", "" })
	local s3 = P.sanitize({ calling = "Fang", callingChanges = 2, callingChangedAt = 55 })
	T.eq({ s3.calling, s3.callingChanges, s3.callingChangedAt }, { "Fang", 2, 55 })
end)
