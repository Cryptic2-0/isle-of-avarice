--!strict
local T = require("./harness")
local Crown = require("../src/shared/Rules/Crown")
local Relics = require("../src/shared/Catalog/Relics")
local Types = require("../src/shared/Types")

local function full(): Types.Ledger
	local claimed: { [string]: boolean } = {}
	for _, relic in Relics.list do
		claimed[relic.id] = true
	end
	return { claimed = claimed, free = {} }
end

local function rec(crowns: number, stars: number): Types.CrownRecord
	return { crowns = crowns, stars = stars, boardCrowns = 0, badgeAwarded = false }
end

T.test("a new record and the constants", function()
	T.eq(Crown.newRecord(), { crowns = 0, stars = 0, boardCrowns = 0, badgeAwarded = false })
	T.eq({ Crown.MAX, Crown.MAX_GEMS, Crown.RENOUNCE_HINT }, {
		1000000,
		6,
		"You may Renounce at the Tally Stone in Tallyport.",
	})
end)

T.test("one Crown per run, only for a complete Ledger", function()
	T.truthy(Crown.canCrown(rec(0, 0), full()))
	T.truthy(Crown.canCrown(rec(1, 1), full()))
	T.falsy(Crown.canCrown(rec(1, 0), full()), "this run already gave its Crown")
	local missing = full()
	missing.claimed.R050 = nil
	T.falsy(Crown.canCrown(rec(0, 0), missing))
	T.falsy(Crown.canCrown(rec(0, 0), { claimed = {}, free = { "R050" } }))
	T.eq(Crown.crown(rec(0, 0)), rec(1, 0))
	T.eq(Crown.crown(rec(1, 1)), rec(2, 1))
	T.eq(Crown.crown(rec(1, 0)), rec(1, 0))
	T.falsy(Crown.canCrown(rec(Crown.MAX, Crown.MAX), full()))
	T.eq(Crown.crown(rec(Crown.MAX, Crown.MAX)), rec(Crown.MAX, Crown.MAX))
	T.eq({
		Crown.crownedThisRun(rec(1, 0)),
		Crown.crownedThisRun(rec(1, 1)),
		Crown.crownedThisRun(rec(0, 0)),
	}, { true, false, false })
end)

T.test("sanitize: any saved value gives a valid record", function()
	T.eq(Crown.sanitize(nil), Crown.newRecord())
	for _, junk in { "x", 5, true } :: { any } do
		T.eq(Crown.sanitize(junk), Crown.newRecord(), tostring(junk))
	end
	T.eq(
		Crown.sanitize({ crowns = 3, stars = 2, boardCrowns = 3, badgeAwarded = true }),
		{ crowns = 3, stars = 2, boardCrowns = 3, badgeAwarded = true }
	)
	T.eq(
		Crown.sanitize({ crowns = 3, stars = 3 }),
		{ crowns = 3, stars = 3, boardCrowns = 0, badgeAwarded = false }
	)
	for _, bad in { -1, 1.5, 0 / 0, math.huge, "2", {}, Crown.MAX + 1 } :: { any } do
		T.eq(Crown.sanitize({ crowns = bad, stars = 0 }).crowns, 0, tostring(bad))
	end
	T.eq(Crown.sanitize({ crowns = 3, stars = 0 }).stars, 2)
	T.eq(Crown.sanitize({ crowns = 3, stars = 9 }).stars, 3)
	for _, bad in { 1.5, 0 / 0, "3", true } :: { any } do
		T.eq(
			Crown.sanitize({ crowns = 3, stars = bad }).stars,
			2,
			tostring(bad) .. " reads as Crowned this run"
		)
	end
	T.eq(Crown.sanitize({ crowns = 3 }).stars, 2)
	T.eq(Crown.sanitize({ crowns = 0, stars = 4 }).stars, 0)
	T.eq(Crown.sanitize({ crowns = 2, stars = 1, boardCrowns = 7 }).boardCrowns, 2)
	for _, bad in { -1, 0.5, 0 / 0, "1" } :: { any } do
		T.eq(
			Crown.sanitize({ crowns = 2, stars = 1, boardCrowns = bad }).boardCrowns,
			0,
			tostring(bad)
		)
	end
	T.eq(Crown.sanitize({ crowns = 1, stars = 0, badgeAwarded = "yes" }).badgeAwarded, false)
	-- a damaged save never gives a free Crown: a complete Ledger cannot Crown a sanitized "Crowned this run"
	T.falsy(Crown.canCrown(Crown.sanitize({ crowns = 3, stars = "x" }), full()))
end)

T.test("titles", function()
	T.eq({
		Crown.title(0, 0),
		Crown.title(1, 0),
		Crown.title(2, 1),
		Crown.title(3, 3),
		Crown.title(1, 1),
	}, { "", "Crowned", "Crowned twice ★1", "Crowned 3 times ★3", "Crowned ★1" })
	for _, bad in { -1, 1.5, 0 / 0, math.huge, "1" } :: { any } do
		T.eq(Crown.title(bad, 0), "", tostring(bad))
	end
	T.eq(Crown.title(nil, nil), "")
	T.eq(Crown.title(2, 0 / 0), "Crowned twice")
	T.eq(Crown.title(2, 5), "Crowned twice ★2")
	T.eq(Crown.title(2, -1), "Crowned twice")
end)

T.test("the book line", function()
	T.eq(Crown.bookLine(0, 0, false), "")
	T.eq(Crown.bookLine(0, 0, true), "")
	T.eq(Crown.bookLine(1, 0, true), "Crowned. You may Renounce at the Tally Stone in Tallyport.")
	T.eq(Crown.bookLine(1, 0, false), "Crowned")
	T.eq(Crown.bookLine(1, 1, true), "Crowned ★1")
	T.eq(
		Crown.bookLine(2, 1, true),
		"Crowned twice ★1. You may Renounce at the Tally Stone in Tallyport."
	)
	T.eq(Crown.bookLine(0 / 0, 0, true), "")
end)

T.test("ceremony lines, gems and the badge", function()
	T.eq(
		Crown.ceremonyLines("Ann", 1),
		{ "Ann is Crowned!", "Every Relic of the Ledger is claimed." }
	)
	T.eq(
		Crown.ceremonyLines("Ann", 3),
		{ "Ann is Crowned again: 3 Crowns!", "Every Relic of the Ledger is claimed." }
	)
	T.eq(
		Crown.ceremonyLines("Ann", 0 / 0),
		{ "Ann is Crowned!", "Every Relic of the Ledger is claimed." }
	)
	T.eq({
		Crown.gems(0),
		Crown.gems(1),
		Crown.gems(6),
		Crown.gems(9),
		Crown.gems(-2),
		Crown.gems(1.5),
		Crown.gems(0 / 0),
		Crown.gems("3" :: any),
	}, { 0, 1, 6, 6, 0, 0, 0, 0 })
	local crowned = rec(1, 0)
	T.truthy(Crown.wantsBadge(crowned, 4242))
	T.falsy(Crown.wantsBadge(crowned, 0))
	for _, bad in { -5, 1.5, 0 / 0, "4242", math.huge } :: { any } do
		T.falsy(Crown.wantsBadge(crowned, bad), tostring(bad))
	end
	T.falsy(Crown.wantsBadge(rec(0, 0), 4242))
	T.falsy(Crown.wantsBadge({ crowns = 1, stars = 0, boardCrowns = 0, badgeAwarded = true }, 4242))
end)

T.test("no Crown function mutates its arguments", function()
	local r = rec(1, 0)
	local l = full()
	Crown.canCrown(r, l)
	Crown.crown(r)
	Crown.sanitize(r)
	Crown.wantsBadge(r, 1)
	T.eq(r, rec(1, 0))
	T.eq(l, full())
	local raw = { crowns = 3, stars = 9, boardCrowns = 7 }
	Crown.sanitize(raw)
	T.eq(raw, { crowns = 3, stars = 9, boardCrowns = 7 })
	local fresh = Crown.newRecord()
	fresh.crowns = 5
	T.eq(Crown.newRecord().crowns, 0)
end)
