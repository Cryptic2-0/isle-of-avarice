--!strict
local T = require("./harness")
local LedgerActions = require("../src/shared/Rules/LedgerActions")

local function base(): any
	return { claimed = {}, free = { "R001", "R002" } }
end

T.test("claim, unclaim and discard report the affected card", function()
	T.eq(
		{ LedgerActions.apply(base(), { kind = "claim", freeIndex = 1 }) },
		{ { claimed = { R001 = true }, free = { "R002" } }, "CLAIMED", "R001" }
	)
	T.eq(
		{ LedgerActions.apply({ claimed = { R001 = true }, free = {} }, { kind = "unclaim", cardId = "R001" }) },
		{ { claimed = {}, free = { "R001" } }, "UNCLAIMED", "R001" }
	)
	T.eq(
		{ LedgerActions.apply(base(), { kind = "discard", freeIndex = 2 }) },
		{ { claimed = {}, free = { "R001" } }, "DISCARDED", "R002" }
	)
end)

T.test("apply does not mutate the input ledger", function()
	local input = base()
	LedgerActions.apply(input, { kind = "claim", freeIndex = 1 })
	LedgerActions.apply(input, { kind = "discard", freeIndex = 1 })
	T.eq(input, base())
end)

T.test("nil ledger is DATA_NOT_LOADED", function()
	T.eq({ LedgerActions.apply(nil, { kind = "claim", freeIndex = 1 }) }, { nil, "DATA_NOT_LOADED" })
end)

T.test("hostile payloads are BAD_REQUEST", function()
	local bad: { any } = {
		5,
		"claim",
		true,
		{},
		{ kind = "steal" },
		{ kind = "claim" },
		{ kind = "claim", freeIndex = "1" },
		{ kind = "discard" },
		{ kind = "unclaim" },
		{ kind = "unclaim", cardId = 7 },
		{ kind = "unclaim", cardId = string.rep("R", 17) },
	}
	for i, raw in bad do
		T.eq({ LedgerActions.apply(base(), raw) }, { nil, "BAD_REQUEST" }, `payload {i}`)
	end
	T.eq({ LedgerActions.apply(base(), nil) }, { nil, "BAD_REQUEST" })
end)

T.test("ledger errors pass through", function()
	T.eq({ LedgerActions.apply(base(), { kind = "claim", freeIndex = 21 }) }, { nil, "BAD_INDEX" })
	T.eq({ LedgerActions.apply(base(), { kind = "claim", freeIndex = 0 / 0 }) }, { nil, "BAD_INDEX" })
	T.eq({ LedgerActions.apply(base(), { kind = "discard", freeIndex = 0 }) }, { nil, "BAD_INDEX" })
	T.eq({ LedgerActions.apply(base(), { kind = "unclaim", cardId = "R005" }) }, { nil, "NOT_CLAIMED" })
end)
