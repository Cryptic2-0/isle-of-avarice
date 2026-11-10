--!strict
local T = require("./harness")
local LedgerView = require("../src/shared/Rules/LedgerView")
local Relics = require("../src/shared/Catalog/Relics")

T.test("view of a partly filled Ledger", function()
	local view = LedgerView.build({ claimed = { R002 = true }, free = { "R001", "R002", "R001" } })
	T.eq(view.progressText, "1 / 12")
	T.eq(view.freeText, "3 / 20")
	T.eq(view.complete, false)
	T.eq(#view.slots, 12)
	T.eq(view.slots[1], {
		slot = 1,
		label = "001",
		cardId = "R001",
		name = "Tarnished Tally-Coin",
		tier = "Copper",
		claimed = false,
		spares = 2,
	})
	T.eq(view.slots[2].claimed, true)
	T.eq(view.slots[2].spares, 1)
	T.eq(view.free[1], {
		index = 1,
		cardId = "R001",
		name = "Tarnished Tally-Coin",
		tier = "Copper",
		canClaim = true,
	})
	T.eq(view.free[2].canClaim, false)
end)

T.test("view of a completed Ledger", function()
	local claimed: { [string]: boolean } = {}
	for _, relic in Relics.list do
		claimed[relic.id] = true
	end
	local view = LedgerView.build({ claimed = claimed, free = {} })
	T.eq(view.complete, true)
	T.eq(view.progressText, "12 / 12")
	T.eq(view.freeText, "0 / 20")
	T.eq(#view.free, 0)
end)

T.test("view of an empty Ledger", function()
	local view = LedgerView.build({ claimed = {}, free = {} })
	T.eq(view.progressText, "0 / 12")
	T.eq(view.complete, false)
end)
