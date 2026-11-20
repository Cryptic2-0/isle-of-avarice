--!strict
local T = require("./harness")
local Relics = require("../src/shared/Catalog/Relics")
local Renounce = require("../src/shared/Rules/Renounce")
local Types = require("../src/shared/Types")

local function ready(over: { [string]: any }?): Renounce.State
	local s: { [string]: any } = {
		loaded = true,
		complete = true,
		crowns = 1,
		stars = 0,
		alive = true,
		locked = false,
		claiming = false,
		trading = false,
		inTrial = false,
		inTown = true,
		marked = false,
	}
	for k, v in over or {} do
		s[k] = v
	end
	return s :: any
end

local function completeLedger(free: { string }): Types.Ledger
	local claimed: { [string]: boolean } = {}
	for _, relic in Relics.list do
		claimed[relic.id] = true
	end
	return { claimed = claimed, free = free }
end

T.test("constants", function()
	T.eq(
		{ Renounce.OFFER_SECONDS, Renounce.FIGHT_SECONDS, Renounce.WORD, Renounce.MAX_WORD_LENGTH },
		{ 60, 30, "RENOUNCE", 32 } :: { any }
	)
end)

T.test("check: every refusal, in order", function()
	T.eq({ Renounce.check(ready(), 1000) }, { true, "RENOUNCE_OFFER" } :: { any })
	local cases: { { any } } = {
		{ { loaded = false, alive = false, inTown = false }, "DATA_NOT_LOADED" },
		{ { complete = false, alive = false }, "RENOUNCE_NOT_READY" },
		{ { stars = 1, alive = false }, "RENOUNCE_NOT_READY" },
		{ { crowns = 0, stars = 0 }, "RENOUNCE_NOT_READY" },
		{ { alive = false, locked = true }, "EDICT_NOT_NOW" },
		{ { locked = true, claiming = true }, "LEDGER_LOCKED" },
		{ { claiming = true, trading = true }, "RENOUNCE_CLAIMING" },
		{ { trading = true, inTrial = true }, "RENOUNCE_TRADING" },
		{ { inTrial = true, inTown = false }, "EDICT_IN_TRIAL" },
		{ { inTown = false, marked = true }, "RENOUNCE_NOT_IN_TOWN" },
		{ { marked = true, lastFightAt = 999 }, "EDICT_MARKED" },
		{ { lastFightAt = 971 }, "EDICT_IN_COMBAT" },
		{ { lastFightAt = 0 / 0 }, "EDICT_IN_COMBAT" },
	}
	for _, case in cases do
		T.eq({ Renounce.check(ready(case[1]), 1000) }, { false, case[2] } :: { any }, case[2])
	end
	T.eq(
		{ Renounce.check(ready({ lastFightAt = 970 }), 1000) },
		{ true, "RENOUNCE_OFFER" } :: { any }
	)
	T.eq(
		{ Renounce.check(ready({ crowns = 3, stars = 2 }), 1000) },
		{ true, "RENOUNCE_OFFER" } :: { any }
	)
	T.eq(
		{ Renounce.check(ready(), 0 / 0) },
		{ true, "RENOUNCE_OFFER" } :: { any },
		"no fight on record"
	)
end)

T.test("parse: only confirm and cancel", function()
	T.eq({ Renounce.parse({ kind = "cancel" }) }, { { kind = "cancel" }, "OK" } :: { any })
	T.eq(
		{ Renounce.parse({ kind = "confirm", word = "RENOUNCE" }) },
		{ { kind = "confirm", word = "RENOUNCE" }, "OK" } :: { any }
	)
	T.eq(
		{ Renounce.parse({ kind = "confirm", word = 5 }) },
		{ { kind = "confirm", word = "" }, "OK" } :: { any }
	)
	T.eq(
		{ Renounce.parse({ kind = "confirm" }) },
		{ { kind = "confirm", word = "" }, "OK" } :: { any }
	)
	T.eq(
		{ Renounce.parse({ kind = "confirm", word = string.rep("R", 33) }) },
		{ { kind = "confirm", word = "" }, "OK" } :: { any }
	)
	for _, bad in { "confirm", 5, true, {}, { kind = "steal" }, { kind = 5 } } :: { any } do
		T.eq({ Renounce.parse(bad) }, { nil, "BAD_REQUEST" } :: { any }, tostring(bad))
	end
	T.eq({ Renounce.parse(nil) }, { nil, "BAD_REQUEST" } :: { any })
end)

T.test("the word", function()
	for _, word in { "RENOUNCE", "renounce", "  Renounce  ", "ReNoUnCe" } do
		T.truthy(Renounce.wordMatches(word), word)
	end
	for _, word in
		{ "", "RENOUNC", "RENOUNCE!", "re nounce", "renounce please", "RENOUNCE RENOUNCE" }
	do
		T.falsy(Renounce.wordMatches(word), word)
	end
	T.falsy(Renounce.wordMatches(5))
	T.falsy(Renounce.wordMatches(nil))
end)

T.test("confirm: an offer, still open, and the word", function()
	local offer = Renounce.offer(1000)
	T.eq(offer, { expiresAt = 1060 })
	T.eq({ Renounce.confirm(offer, "RENOUNCE", 1030) }, { true, "OK" } :: { any })
	T.eq({ Renounce.confirm(nil, "RENOUNCE", 1030) }, { false, "RENOUNCE_NO_OFFER" } :: { any })
	T.eq({ Renounce.confirm(offer, "RENOUNCE", 1060) }, { false, "RENOUNCE_EXPIRED" } :: { any })
	T.eq({ Renounce.confirm(offer, "RENOUNCE", 0 / 0) }, { false, "RENOUNCE_EXPIRED" } :: { any })
	T.eq({ Renounce.confirm(offer, "nope", 1030) }, { false, "RENOUNCE_WORD" } :: { any })
	T.eq({ Renounce.confirm(offer, "nope", 1070) }, { false, "RENOUNCE_EXPIRED" } :: { any })
end)

T.test("apply: every card goes back, the rest is kept, a star is earned", function()
	local parts: Renounce.Parts = {
		ledger = completeLedger({ "E001", "R001", "R007" }),
		vault = { R007 = true, R010 = true },
		crown = { crowns = 2, stars = 1, boardCrowns = 2, badgeAwarded = true },
		trials = { cooldowns = { tidewalk = 5300 }, questStep = 2 },
		rounds = { wardens = { "tidewalk", "salt_post" }, beasts = { "brinehound" } },
	}
	local out = Renounce.apply(parts)
	T.eq(out, {
		ledger = { claimed = {}, free = {} },
		vault = {},
		crown = { crowns = 2, stars = 2, boardCrowns = 2, badgeAwarded = true },
		trials = { cooldowns = { tidewalk = 5300 }, questStep = 0 },
		rounds = { wardens = {}, beasts = {} },
	})
	T.eq(parts.ledger, completeLedger({ "E001", "R001", "R007" }))
	T.eq(parts.vault, { R007 = true, R010 = true })
	T.eq(parts.crown, { crowns = 2, stars = 1, boardCrowns = 2, badgeAwarded = true })
	T.eq(parts.trials, { cooldowns = { tidewalk = 5300 }, questStep = 2 })
	T.eq(parts.rounds, { wardens = { "tidewalk", "salt_post" }, beasts = { "brinehound" } })
	out.trials.cooldowns.salt_post = 1
	T.eq(parts.trials.cooldowns, { tidewalk = 5300 })
end)

T.test("offer lines", function()
	T.eq(Renounce.offerLines({ crowns = 1, stars = 0, boardCrowns = 0, badgeAwarded = false }), {
		"Every card in your Ledger goes back to the island: all 50 claimed Relics, your spare Relics and your Edicts.",
		"Your Vault empties. The Unpaid Debt, the Warden's Round and the Beast Tally start again.",
		"You keep your Coin, your Paths and abilities, your trial cooldowns and your Crowns.",
		'You earn a star and will show as "Crowned ★1".',
		"This cannot be undone.",
	})
	T.eq(
		Renounce.offerLines({ crowns = 2, stars = 1, boardCrowns = 0, badgeAwarded = false })[4],
		'You earn a star and will show as "Crowned twice ★2".'
	)
end)
