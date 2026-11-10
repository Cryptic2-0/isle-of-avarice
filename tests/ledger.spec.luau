--!strict
local T = require("./harness")
local Ledger = require("../src/shared/Rules/Ledger")
local Relics = require("../src/shared/Catalog/Relics")
local Types = require("../src/shared/Types")

type LedgerT = Types.Ledger

local function fullFree(): LedgerT
	local free = {}
	for _ = 1, Ledger.FREE_SLOTS do
		table.insert(free, "R001")
	end
	return { claimed = {}, free = free }
end

T.test("new is empty", function()
	T.eq(Ledger.new(), { claimed = {}, free = {} })
	T.eq(Ledger.FREE_SLOTS, 20)
end)

T.test("add appends and rejects unknown cards", function()
	T.eq(Ledger.add(Ledger.new(), "R001"), { claimed = {}, free = { "R001" } })
	T.eq(Ledger.add({ claimed = {}, free = { "R002" } }, "R001"), { claimed = {}, free = { "R002", "R001" } })
	T.eq({ Ledger.add(Ledger.new(), "R999") }, { nil, "UNKNOWN_CARD" })
end)

T.test("add rejects the 21st free card", function()
	T.eq({ Ledger.add(fullFree(), "R002") }, { nil, "FREE_FULL" })
	local nineteen = fullFree()
	table.remove(nineteen.free)
	local result = Ledger.add(nineteen, "R002")
	T.eq(result and #result.free, 20)
end)

T.test("add does not mutate its input", function()
	local input: LedgerT = { claimed = { R003 = true }, free = { "R001" } }
	local copy: LedgerT = { claimed = { R003 = true }, free = { "R001" } }
	local result = Ledger.add(input, "R002")
	T.eq(input, copy)
	T.truthy(result ~= input)
end)

T.test("claim moves a free card to claimed and shifts the rest", function()
	T.eq(
		Ledger.claim({ claimed = {}, free = { "R001", "R002", "R003" } }, 2),
		{ claimed = { R002 = true }, free = { "R001", "R003" } }
	)
	T.eq({ Ledger.claim({ claimed = { R002 = true }, free = { "R002" } }, 1) }, { nil, "ALREADY_CLAIMED" })
end)

T.test("claim does not mutate its input", function()
	local input: LedgerT = { claimed = {}, free = { "R001", "R002" } }
	Ledger.claim(input, 1)
	T.eq(input, { claimed = {}, free = { "R001", "R002" } })
end)

T.test("claim rejects bad indexes", function()
	for _, bad in { 0, 2, -1, 1.5, 0 / 0, math.huge, -math.huge } do
		T.eq({ Ledger.claim({ claimed = {}, free = { "R001" } }, bad) }, { nil, "BAD_INDEX" }, tostring(bad))
	end
end)

T.test("unclaim returns the card to free", function()
	T.eq(Ledger.unclaim({ claimed = { R002 = true }, free = {} }, "R002"), { claimed = {}, free = { "R002" } })
	T.eq({ Ledger.unclaim(Ledger.new(), "R002") }, { nil, "NOT_CLAIMED" })
	local full = fullFree()
	full.claimed.R002 = true
	T.eq({ Ledger.unclaim(full, "R002") }, { nil, "FREE_FULL" })
end)

T.test("discard removes and shifts", function()
	T.eq(Ledger.discard({ claimed = {}, free = { "R001", "R002" } }, 1), { claimed = {}, free = { "R002" } })
	for _, bad in { 0, 3, -1, 1.5, 0 / 0, math.huge } do
		T.eq({ Ledger.discard({ claimed = {}, free = { "R001", "R002" } }, bad) }, { nil, "BAD_INDEX" }, tostring(bad))
	end
	local input: LedgerT = { claimed = {}, free = { "R001", "R002" } }
	Ledger.discard(input, 1)
	T.eq(input, { claimed = {}, free = { "R001", "R002" } })
end)

T.test("count and claimedCount", function()
	T.eq(Ledger.count({ claimed = { R001 = true }, free = { "R001", "R001", "R002" } }, "R001"), 3)
	T.eq(Ledger.count({ claimed = {}, free = { "R002" } }, "R001"), 0)
	T.eq(Ledger.claimedCount({ claimed = { R001 = true, R002 = true }, free = {} }), 2)
	T.eq(Ledger.claimedCount(Ledger.new()), 0)
end)

T.test("isComplete needs every relic claimed", function()
	local claimed: { [string]: boolean } = {}
	for i, relic in Relics.list do
		if i < Relics.count then
			claimed[relic.id] = true
		end
	end
	T.falsy(Ledger.isComplete({ claimed = claimed, free = { "R012", "R012" } }), "11 claimed plus spares")
	claimed.R012 = true
	T.truthy(Ledger.isComplete({ claimed = claimed, free = {} }), "all 12")
	T.falsy(Ledger.isComplete(Ledger.new()))
end)

T.test("sanitize handles junk without erroring", function()
	T.eq(Ledger.sanitize(nil), Ledger.new())
	T.eq(Ledger.sanitize("junk"), Ledger.new())
	T.eq(Ledger.sanitize(42), Ledger.new())
	T.eq(Ledger.sanitize({ claimed = "x", free = 7 }), Ledger.new())
	T.eq(Ledger.sanitize({}), Ledger.new())
end)

T.test("sanitize keeps only valid entries", function()
	local raw: any = {
		claimed = { R001 = true, R999 = true, R002 = "yes", R003 = false, [5] = true },
		free = { "R003", 42, "R999", "R003" },
	}
	T.eq(Ledger.sanitize(raw), { claimed = { R001 = true }, free = { "R003", "R003" } })
end)

T.test("sanitize cuts free to the first 20", function()
	local free = {}
	for i = 1, 25 do
		free[i] = if i <= 20 then "R001" else "R002"
	end
	local result = Ledger.sanitize({ claimed = {}, free = free })
	T.eq(#result.free, 20)
	T.eq(result.free[20], "R001")
end)
