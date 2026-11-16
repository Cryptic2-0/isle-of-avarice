--!strict
local T = require("./harness")
local Trade = require("../src/shared/Rules/Trade")
local Types = require("../src/shared/Types")

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

local A, B = 11, 22
local ledgerA: Types.Ledger =
	{ claimed = { R009 = true }, free = { "R001", "R007", "E002", "R001" } }
local ledgerB: Types.Ledger = { claimed = {}, free = { "R010", "E005" } }

-- A offers R007 and 30 Coin; B offers R010.
local function offered(): Trade.Session
	local s = Trade.new(A, B, 100)
	local s1 = Trade.setOffer(s, A, { cards = { "R007" }, coin = 30 }, ledgerA, 50, 101)
	local s2 =
		Trade.setOffer(s1 :: Trade.Session, B, { cards = { "R010" }, coin = 0 }, ledgerB, 5, 102)
	return s2 :: Trade.Session
end

local function bothConfirmed(): Trade.Session
	local s = offered()
	local s1 = Trade.confirm(s, A, 104)
	local s2 = Trade.confirm(s1 :: Trade.Session, B, 104)
	return s2 :: Trade.Session
end

T.test("constants and a new session", function()
	T.eq({
		Trade.MAX_CARDS,
		Trade.INVITE_RANGE,
		Trade.KEEP_RANGE,
		Trade.CONFIRM_DELAY,
		Trade.INVITE_SECONDS,
	}, { 6, 15, 25, 2, 20 })
	T.eq(Trade.new(A, B, 100), {
		a = A,
		b = B,
		offers = { ["11"] = { cards = {}, coin = 0 }, ["22"] = { cards = {}, coin = 0 } },
		confirmed = {},
		changedAt = 100,
	})
	local s = Trade.new(A, B, 100)
	T.eq({ Trade.has(s, A), Trade.has(s, B), Trade.has(s, 33) }, { true, true, false })
	T.eq({ Trade.other(s, A), Trade.other(s, B) }, { B, A })
end)

T.test("setOffer: free-slot cards and Coin the player really has", function()
	local s = Trade.new(A, B, 100)
	local s1, code =
		Trade.setOffer(s, A, { cards = { "R001", "E002", "R001" }, coin = 50 }, ledgerA, 50, 101)
	T.eq(code, "OK")
	T.eq((s1 :: Trade.Session).offers["11"], { cards = { "R001", "E002", "R001" }, coin = 50 })
	T.eq((s1 :: Trade.Session).changedAt, 101)
	local refused: { { any } } = {
		{ { cards = { "R001", "R001", "R001" }, coin = 0 }, "TRADE_BAD_OFFER" }, -- holds two
		{ { cards = { "R009" }, coin = 0 }, "TRADE_BAD_OFFER" }, -- claimed, not spare
		{ { cards = { "R010" }, coin = 0 }, "TRADE_BAD_OFFER" }, -- the other player's
		{ { cards = {}, coin = 51 }, "TRADE_BAD_OFFER" }, -- more Coin than held
		{
			{ cards = { "R001", "R007", "E002", "R001", "R001", "R001", "R001" }, coin = 0 },
			"TRADE_BAD_OFFER",
		},
		{ { cards = { "nope" }, coin = 0 }, "BAD_REQUEST" },
		{ { cards = { 5 }, coin = 0 }, "BAD_REQUEST" },
		{ { cards = "R001", coin = 0 }, "BAD_REQUEST" },
		{ { cards = { a = "R001" }, coin = 0 }, "BAD_REQUEST" },
		{ { coin = 0 }, "BAD_REQUEST" },
		{ { cards = {} }, "BAD_REQUEST" },
		{ { cards = {}, coin = -1 }, "BAD_REQUEST" },
		{ { cards = {}, coin = 1.5 }, "BAD_REQUEST" },
		{ { cards = {}, coin = 0 / 0 }, "BAD_REQUEST" },
		{ { cards = {}, coin = math.huge }, "BAD_REQUEST" },
		{ { cards = {}, coin = "5" }, "BAD_REQUEST" },
		{ "junk", "BAD_REQUEST" },
		{ 7, "BAD_REQUEST" },
	}
	for i, case in refused do
		T.eq(
			{ Trade.setOffer(s, A, case[1], ledgerA, 50, 101) },
			{ nil, case[2] } :: { any },
			"case " .. i
		)
	end
	T.eq({ Trade.setOffer(s, A, nil, ledgerA, 50, 101) }, { nil, "BAD_REQUEST" } :: { any })
	T.eq(
		{ Trade.setOffer(s, 33, { cards = {}, coin = 0 }, ledgerA, 50, 101) },
		{ nil, "TRADE_NOT_OPEN" } :: { any }
	)
	T.eq(
		{ Trade.setOffer(s, A, { cards = {}, coin = 0 }, nil, 50, 101) },
		{ nil, "DATA_NOT_LOADED" } :: { any }
	)
	-- Coin that is not a real number covers nothing.
	T.eq(
		{ Trade.setOffer(s, A, { cards = {}, coin = 1 }, ledgerA, 0 / 0, 101) },
		{ nil, "TRADE_BAD_OFFER" } :: { any }
	)
end)

T.test("confirm: both must, and not within 2 seconds of a change", function()
	local s = offered()
	T.falsy(Trade.ready(s))
	T.eq({ Trade.confirm(s, A, 103.9) }, { nil, "TRADE_TOO_SOON" } :: { any })
	T.eq({ Trade.confirm(s, A, 0 / 0) }, { nil, "TRADE_TOO_SOON" } :: { any })
	T.eq({ Trade.confirm(s, 33, 110) }, { nil, "TRADE_NOT_OPEN" } :: { any })
	local s1, code = Trade.confirm(s, A, 104)
	T.eq(code, "OK")
	T.eq((s1 :: Trade.Session).confirmed, { ["11"] = true })
	T.falsy(Trade.ready(s1 :: Trade.Session))
	local s2 = Trade.confirm(s1 :: Trade.Session, B, 104)
	T.truthy(Trade.ready(s2 :: Trade.Session))
	T.eq(s.confirmed, {}, "the session is not changed in place")
end)

T.test("any change clears both confirmations: no last-moment switch", function()
	local s = bothConfirmed()
	-- B swaps the Gold Relic for nothing after A confirmed.
	local switched =
		Trade.setOffer(s, B, { cards = {}, coin = 0 }, ledgerB, 5, 110) :: Trade.Session
	T.eq(switched.confirmed, {})
	T.falsy(Trade.ready(switched))
	T.eq(switched.changedAt, 110)
	T.eq({ Trade.confirm(switched, B, 111) }, { nil, "TRADE_TOO_SOON" } :: { any })
	T.eq(select(2, Trade.confirm(switched, B, 112)), "OK")
	-- Sending the same offer again also counts as a change.
	local same =
		Trade.setOffer(s, A, { cards = { "R007" }, coin = 30 }, ledgerA, 50, 110) :: Trade.Session
	T.eq(same.confirmed, {})
end)

T.test("settle swaps everything at once", function()
	local s = bothConfirmed()
	local newA, coinA, newB, coinB, code = Trade.settle(s, ledgerA, 50, ledgerB, 5)
	T.eq(code, "TRADE_DONE")
	T.eq(newA, { claimed = { R009 = true }, free = { "R001", "E002", "R001", "R010" } })
	T.eq(newB, { claimed = {}, free = { "E005", "R007" } })
	T.eq({ coinA, coinB }, { 20, 35 })
	-- Nothing is made or lost: the same cards and the same Coin, in other hands.
	T.eq(#(newA :: Types.Ledger).free + #(newB :: Types.Ledger).free, #ledgerA.free + #ledgerB.free)
	T.eq(coinA + coinB, 55)
	T.eq(ledgerA.free, { "R001", "R007", "E002", "R001" }, "inputs are not changed in place")
end)

T.test(
	"settle re-checks the live Ledgers and Coin, and does nothing when anything is off",
	function()
		local s = bothConfirmed()
		local function refused(a: Types.Ledger, ca: number, b: Types.Ledger, cb: number): string
			local newA, coinA, newB, coinB, code = Trade.settle(s, a, ca, b, cb)
			T.eq({ newA, coinA, newB, coinB }, { nil, ca, nil, cb } :: { any })
			return code
		end
		-- Not both confirmed.
		local half = Trade.confirm(offered(), A, 104) :: Trade.Session
		T.eq(select(5, Trade.settle(half, ledgerA, 50, ledgerB, 5)), "TRADE_NOT_OPEN")
		-- A no longer holds the Relic (sold it, lost it to a claim).
		T.eq(refused({ claimed = {}, free = { "R001" } }, 50, ledgerB, 5), "TRADE_BAD_OFFER")
		-- A spent the Coin.
		T.eq(refused(ledgerA, 29, ledgerB, 5), "TRADE_BAD_OFFER")
		T.eq(refused(ledgerA, 0 / 0, ledgerB, 5), "TRADE_BAD_OFFER")
		-- B no longer holds theirs.
		T.eq(refused(ledgerA, 50, { claimed = {}, free = { "E005" } }, 5), "TRADE_BAD_OFFER")
		-- B has no room: 20 free, gives 1, gets 1 is fine; but 20 free and gives none is not.
		local fullB: Types.Ledger = { claimed = {}, free = table.create(19, "R002") }
		table.insert(fullB.free, "R010")
		T.eq(select(5, Trade.settle(s, ledgerA, 50, fullB, 5)), "TRADE_DONE")
		local gift = Trade.new(A, B, 0)
		gift =
			Trade.setOffer(gift, A, { cards = { "R007" }, coin = 0 }, ledgerA, 50, 1) :: Trade.Session
		gift = Trade.confirm(gift, A, 5) :: Trade.Session
		gift = Trade.confirm(gift, B, 5) :: Trade.Session
		local packed: Types.Ledger = { claimed = {}, free = table.create(20, "R002") }
		local _, _, _, _, code = Trade.settle(gift, ledgerA, 50, packed, 5)
		T.eq(code, "TRADE_NO_ROOM")
		-- A one-sided gift with room goes through.
		local gA, _, gB = Trade.settle(gift, ledgerA, 50, ledgerB, 5)
		T.eq((gA :: Types.Ledger).free, { "R001", "E002", "R001" })
		T.eq((gB :: Types.Ledger).free, { "R010", "E005", "R007" })
	end
)

T.test("prune drops an offer its owner can no longer cover", function()
	local s = bothConfirmed()
	-- Still covered: nothing changes, confirmations stay.
	T.eq(Trade.prune(s, A, ledgerA, 50, 120), s)
	-- A lost the Relic: A's offer is emptied and both must confirm again.
	local pruned = Trade.prune(s, A, { claimed = {}, free = { "R001" } }, 50, 120)
	T.eq(pruned.offers["11"], { cards = {}, coin = 0 })
	T.eq(pruned.offers["22"], { cards = { "R010" }, coin = 0 })
	T.eq({ pruned.confirmed, pruned.changedAt }, { {}, 120 } :: { any })
	-- A spent the Coin.
	T.eq(Trade.prune(s, A, ledgerA, 10, 120).offers["11"], { cards = {}, coin = 0 })
	-- Someone who is not in the trade changes nothing.
	T.eq(Trade.prune(s, 33, ledgerA, 0, 120), s)
end)

T.test("view: what each side sees", function()
	local s = Trade.confirm(offered(), B, 104) :: Trade.Session
	local view = Trade.view(s, A, "Bea", ledgerA, 50, 104.5)
	T.eq(view.otherName, "Bea")
	T.eq(view.mine, { cards = { { cardId = "R007", name = "Bottled Squall" } }, coin = 30 })
	T.eq(view.theirs, { cards = { { cardId = "R010", name = "Gilded Anchor Link" } }, coin = 0 })
	T.eq({ view.mineConfirmed, view.theirsConfirmed }, { false, true })
	T.eq(view.coinHeld, 50)
	T.eq(view.confirmIn, 0)
	T.eq(view.status, "Bea has confirmed.")
	T.eq(view.free, {
		{ index = 1, cardId = "R001", name = "Tarnished Tally-Coin", offered = false },
		{ index = 2, cardId = "R007", name = "Bottled Squall", offered = true },
		{ index = 3, cardId = "E002", name = "Audit", offered = false },
		{ index = 4, cardId = "R001", name = "Tarnished Tally-Coin", offered = false },
	})
	local theirs = Trade.view(s, B, "Ada", ledgerB, 5, 104.5)
	T.eq({ theirs.mineConfirmed, theirs.theirsConfirmed }, { true, false })
	T.eq(theirs.status, "You confirmed. Waiting for Ada.")
	T.eq(theirs.mine.cards, { { cardId = "R010", name = "Gilded Anchor Link" } })
	-- Just after a change nobody can confirm yet.
	local fresh = Trade.view(offered(), A, "Bea", ledgerA, 50, 102.5)
	T.eq(fresh.confirmIn, 1.5)
	T.eq(fresh.status, "Check both offers, then confirm.")
	-- Only as many copies as offered are marked.
	local two =
		Trade.setOffer(Trade.new(A, B, 0), A, { cards = { "R001" }, coin = 0 }, ledgerA, 50, 1)
	local marks = {}
	for _, row in Trade.view(two :: Trade.Session, A, "Bea", ledgerA, 50, 9).free do
		table.insert(marks, row.offered)
	end
	T.eq(marks, { true, false, false, false })
end)

T.test("no rule changes its arguments", function()
	local s = bothConfirmed()
	local s0, a0, b0 = copy(s), copy(ledgerA), copy(ledgerB)
	Trade.setOffer(s, A, { cards = { "R001" }, coin = 1 }, ledgerA, 50, 200)
	Trade.confirm(s, A, 200)
	Trade.settle(s, ledgerA, 50, ledgerB, 5)
	Trade.prune(s, A, { claimed = {}, free = {} }, 0, 200)
	Trade.view(s, A, "Bea", ledgerA, 50, 200)
	T.eq({ s, ledgerA, ledgerB }, { s0, a0, b0 } :: { any })
end)

T.test("unconfirm clears both confirmations and restarts the wait", function()
	local s = bothConfirmed()
	local cleared = Trade.unconfirm(s, 150)
	T.eq({ cleared.confirmed, cleared.changedAt }, { {}, 150 } :: { any })
	T.eq(cleared.offers, s.offers)
	T.truthy(Trade.ready(s), "the session is not changed in place")
end)

T.test("nearest: who a trade request goes to", function()
	local me = { userId = 1, position = { x = 0, y = 3, z = 0 } }
	local others = {
		{ userId = 1, position = { x = 0, y = 3, z = 0 } },
		{ userId = 2, position = { x = 14, y = 3, z = 0 } },
		{ userId = 3, position = { x = 0, y = 3, z = 15.1 } },
	}
	T.eq(Trade.nearest(me, others), 2)
	T.eq(Trade.nearest(me, { others[1], others[3] }), nil)
	T.eq(Trade.nearest(me, { { userId = 5, position = { x = 0, y = 3, z = 15 } } }), 5)
	T.eq(Trade.nearest(me, { { userId = 5, position = { x = 0 / 0, y = 3, z = 0 } } }), nil)
end)
