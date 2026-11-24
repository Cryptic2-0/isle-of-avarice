--!strict
local T = require("./harness")
local Creatures = require("../src/shared/Catalog/Creatures")
local R = require("../src/shared/Rules/Rewards")

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = copy(v)
	end
	return out
end

local function always(value: number): () -> number
	return function()
		return value
	end
end

-- Four hits by two players.
local function sample(): R.Tally
	local t = R.record({}, 1, "Strike", 20, 0)
	t = R.record(t, 1, "Ember", 16, 1)
	t = R.record(t, 2, "Fang", 22, 2)
	return R.record(t, 1, "Ember", 3, 3)
end

T.test("record adds up damage per attacker and Path", function()
	T.eq({ R.CONTRIBUTOR_SECONDS, R.STRIKE }, { 30, "Strike" } :: { any })
	local t = sample()
	T.eq(t["1"], { lastAt = 3, hitAt = 3, total = 39, byPath = { Strike = 20, Ember = 19 } })
	T.eq(t["2"], { lastAt = 2, hitAt = 2, total = 22, byPath = { Fang = 22 } })
	for _, bad in { 0, -5, 0 / 0, math.huge } do
		T.eq(R.record(t, 1, "Fang", bad, 4), t)
	end
	local before = copy(t)
	R.record(t, 1, "Fang", 5, 9)
	R.record(t, 3, "Fang", 5, 9)
	T.eq(t, before, "the tally is not changed in place")
end)

T.test("contributors hit it in the last 30 seconds, most damage first", function()
	local t = sample()
	T.eq(
		{ R.contributors(t, 32), R.contributors(t, 32.5), R.contributors(t, 33.5) },
		{ { 1, 2 }, { 1 }, {} } :: { any }
	)
	T.eq(R.contributors(t, 0 / 0), {})
	T.eq(R.contributors(R.record(R.record({}, 9, "Fang", 10, 0), 4, "Fang", 10, 0), 1), { 4, 9 })
	T.eq(R.contributors({}, 0), {})
end)

T.test("XP goes to the Path that dealt the most; the Strike counts as the Calling", function()
	T.eq(R.xpPath({ Strike = 20, Ember = 25 }, "Fang"), "Ember")
	T.eq(
		R.xpPath({ Strike = 20, Fang = 5, Ember = 25 }, "Fang"),
		"Fang",
		"a tie goes to the Calling"
	)
	T.eq(R.xpPath({ Ember = 10, Gale = 10 }, "Fang"), "Gale", "other ties: hexagon order")
	T.eq(R.xpPath({ Strike = 40 }, "Mire"), "Mire")
	T.eq(R.xpPath({ Strike = 40, Ember = 99 }, ""), "", "no Calling, no XP")
	T.eq(R.xpPath({ Nope = 99, Mend = 1 }, "Fang"), "Mend")
	T.eq(R.xpPath({}, "Gale"), "Gale")
end)

-- The Brine Colossus (60 Coin, 500 XP, R022 100%, R023 20%, R043 15%) and six players dealing 60 down to 10.
local col = Creatures.byId.brine_colossus
local function six(): (R.Tally, { [string]: R.Recipient })
	local tally: R.Tally, all = {}, {}
	for id = 1, 6 do
		tally = R.record(tally, id, "Strike", 70 - id * 10, 0)
		all[tostring(id)] = { calling = "Fang", room = 20 }
	end
	return tally, all
end

T.test("awards: every contributor gets Coin and XP; drops obey the server cap", function()
	local tally, all = six()
	local a = R.awards(col, tally, all, {}, 1, always(0.5))
	T.eq(a[1], {
		userId = 1,
		coin = 60,
		xpPath = "Fang",
		xp = 500,
		relics = { "R022" },
		sealed = {},
		lost = {},
	})
	T.eq(
		{ #a, a[4].relics, a[5].relics, a[5].sealed, a[6].sealed },
		{ 6, { "R022" }, {}, { "R022" }, { "R022" } } :: { any },
		"Gold cap 4"
	)
	T.eq(R.awards(col, tally, all, { R022 = 3 }, 1, always(0.5))[2].sealed, { "R022" })
	T.eq(R.awards(col, tally, all, {}, 1, always(0.1))[1].relics, { "R022", "R023", "R043" })
end)

T.test("awards: full slots lose the Relic; no Calling means Coin only", function()
	local tally, all = six()
	local tight = table.clone(all)
	tight["1"] = { calling = "Fang", room = 1 }
	local t1 = R.awards(col, tally, tight, {}, 1, always(0.1))[1]
	T.eq({ t1.relics, t1.lost }, { { "R022" }, { "R023", "R043" } })
	-- A lost Relic does not count against the cap.
	local none = table.clone(all)
	none["1"] = { calling = "Fang", room = 0 }
	local lostAll = R.awards(col, tally, none, { R022 = 3 }, 1, always(0.5))
	T.eq({ lostAll[1].lost, lostAll[2].relics }, { { "R022" }, { "R022" } })
	local bare = table.clone(all)
	bare["1"] = { calling = "", room = 20 }
	local b1 = R.awards(col, tally, bare, {}, 1, always(0.5))[1]
	T.eq({ b1.coin, b1.xpPath, b1.xp }, { 60, "", 0 } :: { any })
end)

T.test("awards: only present, recent contributors; chances are strict", function()
	local tally, all = six()
	T.eq(#R.awards(col, tally, { ["2"] = all["2"] }, {}, 1, always(0.5)), 1)
	T.eq(R.awards(col, tally, { ["2"] = all["2"] }, {}, 1, always(0.5))[1].userId, 2)
	T.eq(#R.awards(col, tally, all, {}, 31, always(0.5)), 0, "nobody hit in the last 30 s")
	local hound, one = Creatures.byId.brinehound, R.record({}, 1, "Strike", 20, 0)
	local me = { ["1"] = { calling = "Fang", room = 20 } }
	T.eq(R.awards(hound, one, me, {}, 1, always(0.0199))[1].relics, { "R019", "R035" })
	T.eq(R.awards(hound, one, me, {}, 1, always(0.02))[1].relics, { "R035" })
	T.eq(R.awards(hound, one, me, {}, 1, always(0 / 0))[1].relics, {}, "a NaN roll wins nothing")
end)

T.test("awards: one roll per drop per contributor, in contributor then drop order", function()
	local reward = {
		coin = 1,
		xp = 1,
		drops = { { relicId = "R019", chance = 0.5 }, { relicId = "R020", chance = 0.5 } },
	}
	local tally = R.record(R.record({}, 5, "Fang", 10, 0), 8, "Fang", 30, 0)
	local both =
		{ ["5"] = { calling = "Fang", room = 20 }, ["8"] = { calling = "Fang", room = 20 } }
	local rolls = { 0.01, 0.99, 0.99, 0.01 }
	local drawn = 0
	local a = R.awards(reward, tally, both, {}, 1, function()
		drawn += 1
		return rolls[drawn]
	end)
	T.eq(drawn, 4)
	T.eq(
		{ a[1].userId, a[1].relics, a[2].userId, a[2].relics },
		{ 8, { "R019" }, 5, { "R020" } } :: { any }
	)
end)

T.test("awards never changes its arguments", function()
	local tally, all = six()
	local held = { R022 = 2 }
	local tally0, all0, held0 = copy(tally), copy(all), copy(held)
	R.awards(col, tally, all, held, 1, always(0.1))
	T.eq({ tally, all, held }, { tally0, all0, held0 } :: { any })
end)

T.test("assist: support that reaches a contributor makes the helper one", function()
	local t = R.record({}, 1, "Strike", 20, 0)
	local before = copy(t)
	local a = R.assist(t, 5, { 1 }, "Mend", 10)
	T.eq(a["5"], { lastAt = 10, total = 0, byPath = {}, assist = "Mend" })
	T.eq(a["1"], t["1"])
	T.eq(R.contributors(a, 20), { 1, 5 })
	T.eq(R.contributors(a, 35), { 5 })
	T.eq(R.assist(t, 5, { 1 }, "Mend", 31), t) -- 1's hit is 31 s old
	T.eq(R.assist(t, 5, { 2 }, "Mend", 10), t) -- 2 never hit it
	T.eq(R.assist(t, 5, {}, "Mend", 10), t)
	T.eq(R.assist(t, 1, { 1 }, "Mend", 10), t) -- helping yourself is not an assist
	T.eq(R.assist(t, 5, { 1 }, "Nope", 10), t)
	T.eq(R.assist(t, 5, { 1 }, "Mend", 0 / 0), t)
	local both = R.assist(R.record(t, 5, "Mend", 14, 5), 5, { 1 }, "Mend", 12)
	T.eq(both["5"], { lastAt = 12, hitAt = 5, total = 14, byPath = { Mend = 14 }, assist = "Mend" })
	T.eq(t, before)
end)

T.test(
	"assist: only an ally who really hit counts, and an assist never touches the ally",
	function()
		local t = R.record({}, 1, "Strike", 20, 0)
		-- B (5) assists A (1); C (6) assists B, who only supported: C is no contributor.
		local ab = R.assist(t, 5, { 1 }, "Mend", 10)
		T.eq(ab["5"].hitAt, nil)
		local abc = R.assist(ab, 6, { 5 }, "Mend", 11)
		T.eq(abc, ab)
		T.eq(abc["6"], nil)
		T.eq(R.contributors(abc, 12), { 1, 5 })
		-- A hit at 0; B assists at 29 (counts); at 31 A's last hit is 31 s old.
		local first = R.assist(t, 5, { 1 }, "Mend", 29)
		T.eq(first["1"], t["1"], "the ally's entry is not changed by an assist")
		T.eq(first["5"].hitAt, nil)
		T.eq(R.assist(first, 5, { 1 }, "Mend", 31), first)
		-- A fresh hit by A makes it count again; the helper's own hitAt is kept through an assist.
		local again = R.record(first, 1, "Strike", 5, 40)
		local third = R.assist(R.record(again, 5, "Mend", 4, 41), 5, { 1 }, "Mend", 42)
		T.eq(third["5"].hitAt, 41)
		T.eq(third["1"], again["1"])
		-- A NaN time helps nobody.
		T.eq(R.assist(t, 5, { 1 }, "Mend", 0 / 0), t)
	end
)

T.test(
	"awards: an assist-only contributor is paid in the support's Path, and served last",
	function()
		local col = Creatures.byId.brine_colossus
		local t = R.assist(R.record({}, 1, "Strike", 50, 0), 5, { 1 }, "Mend", 1)
		local all =
			{ ["1"] = { calling = "Fang", room = 20 }, ["5"] = { calling = "Mire", room = 20 } }
		local a = R.awards(col, t, all, { R022 = 3 }, 2, always(0.5))
		T.eq(#a, 2)
		T.eq({ a[1].userId, a[1].relics }, { 1, { "R022" } })
		T.eq(a[2], {
			userId = 5,
			coin = 60,
			xpPath = "Mend",
			xp = 500,
			relics = {},
			sealed = { "R022" },
			lost = {},
		})
		local bare = { ["1"] = all["1"], ["5"] = { calling = "", room = 20 } }
		local b = R.awards(col, t, bare, {}, 2, always(0.5))
		T.eq({ b[2].coin, b[2].xpPath, b[2].xp }, { 60, "", 0 })
		local mixed = R.assist(R.record(t, 5, "Strike", 10, 1), 5, { 1 }, "Mend", 2)
		T.eq(R.awards(col, mixed, all, {}, 3, always(0.5))[2].xpPath, "Mire") -- damage rule: Strike = Calling
	end
)
