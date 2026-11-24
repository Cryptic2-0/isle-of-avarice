--!strict
local T = require("./harness")
local Leaderboard = require("../src/shared/Rules/Leaderboard")

T.test("constants", function()
	T.eq(
		{ Leaderboard.ROWS, Leaderboard.REFRESH_SECONDS, Leaderboard.RETRY_SECONDS },
		{ 10, 120, 60 }
	)
end)

T.test("fromPage keeps well-formed rows only", function()
	T.eq(
		Leaderboard.fromPage({ { key = "101", value = 3 }, { key = "202", value = 1 } }),
		{ { userId = 101, crowns = 3 }, { userId = 202, crowns = 1 } }
	)
	T.eq(
		Leaderboard.fromPage({
			{ key = "abc", value = 2 },
			{ key = "-5", value = 2 },
			{ key = "1.5", value = 2 },
			{ key = "0", value = 2 },
			{ key = "7", value = 0 },
			{ key = "8", value = 2.5 },
			{ key = "9", value = 0 / 0 },
			{ key = "10", value = "3" },
			{ key = 11, value = 3 },
			"junk",
			{ key = "12", value = 1e7 },
			{ key = "13", value = 4 },
		} :: { any }),
		{ { userId = 13, crowns = 4 } }
	)
	for _, junk in { "x", 5, true } :: { any } do
		T.eq(Leaderboard.fromPage(junk), {})
	end
	T.eq(Leaderboard.fromPage(nil), {})
	local many = {}
	for i = 1, 15 do
		table.insert(many, { key = tostring(i), value = 20 - i })
	end
	T.eq(#Leaderboard.fromPage(many), 10)
end)

T.test("merge: one row per player, the higher count, best first, ties to the lower id", function()
	local stored =
		{ { userId = 5, crowns = 2 }, { userId = 7, crowns = 2 }, { userId = 9, crowns = 1 } }
	local live = {
		{ userId = 9, crowns = 3 },
		{ userId = -1, crowns = 1 },
		{ userId = 7, crowns = 1 },
		{ userId = 4, crowns = 0 },
	}
	T.eq(Leaderboard.merge(stored, live), {
		{ userId = 9, crowns = 3 },
		{ userId = 5, crowns = 2 },
		{ userId = 7, crowns = 2 },
		{ userId = -1, crowns = 1 },
	})
	local twelve = {}
	for i = 1, 12 do
		table.insert(twelve, { userId = i, crowns = i })
	end
	local top = Leaderboard.merge(twelve, {})
	T.eq({ #top, top[1].userId, top[10].userId }, { 10, 12, 3 })
	T.eq(stored[3], { userId = 9, crowns = 1 }, "inputs unchanged")
	T.eq(#twelve, 12)
end)

T.test("the board's text", function()
	local entries = { { userId = 9, crowns = 3 }, { userId = 5, crowns = 1 } }
	T.eq(Leaderboard.view(entries, { ["9"] = "Ann" }, true), {
		title = "The Crowned",
		subtitle = "All time, every server",
		rows = { "1. Ann: Crowned 3 times", "2. Claimant 5: Crowned" },
	})
	T.eq(Leaderboard.view({}, {}, false), {
		title = "The Crowned",
		subtitle = "This server only: the all-time records cannot be reached",
		rows = { "Nobody has been Crowned yet." },
	})
end)

T.test("shouldWrite: only a higher count, and a minute after a failure", function()
	T.truthy(Leaderboard.shouldWrite(1, 0, nil, 100))
	T.falsy(Leaderboard.shouldWrite(1, 1, nil, 100))
	T.falsy(Leaderboard.shouldWrite(0, 0, nil, 100))
	T.falsy(Leaderboard.shouldWrite(2, 1, 50, 100))
	T.truthy(Leaderboard.shouldWrite(2, 1, 40, 100))
	T.falsy(Leaderboard.shouldWrite(2, 1, 0 / 0, 100))
	T.falsy(Leaderboard.shouldWrite(2, 1, 40, 0 / 0))
end)

T.test("keep: a write never lowers the stored count", function()
	T.eq({
		Leaderboard.keep(nil, 2),
		Leaderboard.keep(5, 2),
		Leaderboard.keep(1, 2),
		Leaderboard.keep("9", 2),
		Leaderboard.keep(0 / 0, 2),
		Leaderboard.keep(-3, 2),
		Leaderboard.keep(2.5, 2),
	}, { 2, 5, 2, 2, 2, 2, 2 })
end)

T.test("shouldAskName: once, then again only 300 s after a failed try", function()
	T.eq(Leaderboard.NAME_RETRY_SECONDS, 300)
	T.falsy(Leaderboard.shouldAskName(true, nil, 0), "known")
	T.truthy(Leaderboard.shouldAskName(false, nil, 0), "never tried")
	T.falsy(Leaderboard.shouldAskName(false, 100, 399), "too soon")
	T.truthy(Leaderboard.shouldAskName(false, 100, 400), "300 s later")
	T.falsy(Leaderboard.shouldAskName(true, 100, 1000), "known after a failure")
	T.falsy(Leaderboard.shouldAskName(false, 100, 0 / 0), "a broken clock waits")
end)
