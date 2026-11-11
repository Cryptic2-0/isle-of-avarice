--!strict
local T = require("./harness")
local Scarcity = require("../src/shared/Rules/Scarcity")
local Types = require("../src/shared/Types")

type LedgerT = Types.Ledger

-- R007 is Silver (cap 8), R010 Gold (cap 4), R012 Platinum (cap 2), R001 Copper (no cap)

T.test("countHeld adds claimed and spare copies across ledgers", function()
	local ledgers: { LedgerT } = {
		{ claimed = { R007 = true }, free = { "R007" } },
		{ claimed = {}, free = { "R007", "R001" } },
	}
	T.eq(Scarcity.countHeld(ledgers, "R007"), 3)
	T.eq(Scarcity.countHeld(ledgers, "R001"), 1)
	T.eq(Scarcity.countHeld(ledgers, "R010"), 0)
	T.eq(Scarcity.countHeld({}, "R007"), 0)
end)

T.test("isSealed once held reaches the tier cap", function()
	T.falsy(Scarcity.isSealed("R007", 7))
	T.truthy(Scarcity.isSealed("R007", 8))
	T.truthy(Scarcity.isSealed("R007", 9))
	T.falsy(Scarcity.isSealed("R010", 3))
	T.truthy(Scarcity.isSealed("R010", 4))
	T.falsy(Scarcity.isSealed("R012", 1))
	T.truthy(Scarcity.isSealed("R012", 2))
end)

T.test("uncapped tiers and unknown ids are never sealed", function()
	T.falsy(Scarcity.isSealed("R001", 1000))
	T.falsy(Scarcity.isSealed("R999", 5))
end)
