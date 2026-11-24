--!strict
local T = require("./harness")
local Rounds = require("../src/shared/Rules/Rounds")

T.test("a new record has every round empty", function()
	T.eq(Rounds.new(), { wardens = {}, beasts = {} })
end)

T.test("advance: each step once; the last completes the round and empties it", function()
	local r, code = Rounds.advance(Rounds.new(), "beasts", "shellback")
	T.eq({ r, code }, { { wardens = {}, beasts = { "shellback" } }, "ROUND_STEP" } :: { any })
	T.eq({ Rounds.advance(r, "beasts", "shellback") }, { r, "" } :: { any })
	T.eq(select(2, Rounds.advance(r, "beasts", "drowned_tallyman")), "")
	T.eq(select(2, Rounds.advance(r, "beasts", "tidewalk")), "")
	T.eq(select(2, Rounds.advance(r, "nope", "shellback")), "")
	local all = r
	for _, step in { "brinehound", "bogspitter", "brine_colossus" } do
		all = (Rounds.advance(all, "beasts", step))
	end
	T.eq(all.beasts, { "shellback", "brinehound", "bogspitter", "brine_colossus" })
	T.eq(
		{ Rounds.advance(all, "beasts", "gilded_bailiff") },
		{ { wardens = {}, beasts = {} }, "ROUND_COMPLETE" } :: { any }
	)
	T.eq(
		select(2, Rounds.advance(Rounds.new(), "wardens", "grand_tally")),
		"",
		"the Crown trial is not in the round"
	)
	T.eq(select(2, Rounds.advance(Rounds.new(), "wardens", "reed_run")), "ROUND_STEP")
end)

T.test("sanitize keeps known steps of each round, in order, once", function()
	T.eq(Rounds.sanitize(nil), Rounds.new())
	T.eq(Rounds.sanitize("x"), Rounds.new())
	T.eq(
		Rounds.sanitize({
			wardens = { "salt_post", "nope", "salt_post", 5, "tidewalk", "brinehound" },
			beasts = "x",
			other = { "tidewalk" },
		}),
		{ wardens = { "salt_post", "tidewalk" }, beasts = {} }
	)
	T.eq(
		Rounds.sanitize({
			beasts = { "brinehound", "shellback", "bogspitter", "brine_colossus", "gilded_bailiff" },
		}).beasts,
		{},
		"a saved round never holds every step"
	)
end)

T.test("the HUD line", function()
	T.eq(Rounds.line(Rounds.new()), "Warden's Round 0 / 9, Beast Tally 0 / 5")
	T.eq(
		Rounds.line({ wardens = { "tidewalk", "reed_run" }, beasts = { "shellback" } }),
		"Warden's Round 2 / 9, Beast Tally 1 / 5"
	)
	T.eq(Rounds.line(nil), "Warden's Round 0 / 9, Beast Tally 0 / 5")
	T.eq(Rounds.line({ wardens = "x" }), "Warden's Round 0 / 9, Beast Tally 0 / 5")
end)

T.test("no Rounds function mutates its arguments", function()
	local r = { wardens = { "tidewalk" }, beasts = {} }
	Rounds.advance(r, "wardens", "salt_post")
	Rounds.sanitize(r)
	Rounds.line(r)
	T.eq(r, { wardens = { "tidewalk" }, beasts = {} })
	local nearly =
		{ wardens = {}, beasts = { "brinehound", "shellback", "bogspitter", "brine_colossus" } }
	Rounds.advance(nearly, "beasts", "gilded_bailiff")
	T.eq(#nearly.beasts, 4)
end)
