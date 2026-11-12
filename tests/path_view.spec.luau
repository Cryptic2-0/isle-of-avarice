--!strict
local T = require("./harness")
local P = require("../src/shared/Rules/PathProgress")
local PathView = require("../src/shared/Rules/PathView")

local function make(): any
	local p = P.new()
	p.calling = "Fang"
	p.xp.Fang = 4600
	p.xp.Gale = 300
	p.loadout = { "lunge", "", "", "" }
	return p
end

T.test("build rows and slots", function()
	local p = make()
	local v = PathView.build(p, 0, 1000)
	T.eq({ v.needsCalling, v.callingText }, { false, "Calling: Fang" })
	local fang = v.rows[1]
	T.eq(
		{ fang.path, fang.level, fang.xpText, fang.rateText, fang.isCalling, fang.changeText },
		{ "Fang", 10, "100 / 1000", "100%", true, "" }
	)
	T.eq(
		{ fang.abilities[1].unlocked, fang.abilities[1].equippedSlot, fang.abilities[3].unlocked },
		{ true, 1, false }
	)
	T.eq({ v.rows[4].rateText, v.rows[4].changeText, v.rows[4].canChange }, { "40%", "Free", true })
	T.eq(v.slots[1], { slot = 1, abilityId = "lunge", name = "Lunge" })
	T.eq(v.slots[2].name, "")
	T.eq(#v.slots, 4)
end)

T.test("change cost and cooldown text", function()
	local p = make()
	p.callingChanges = 1
	p.callingChangedAt = 1000
	local v = PathView.build(p, 0, 1000 + 86400)
	T.eq({ v.rows[2].changeText, v.rows[2].canChange }, { "Available in 6 days", false })
	v = PathView.build(p, 0, 1000 + 86400 + 1)
	T.eq(v.rows[2].changeText, "Available in 6 days")
	local after = 1000 + P.CHANGE_COOLDOWN
	v = PathView.build(p, 499, after)
	T.eq({ v.rows[2].changeText, v.rows[2].canChange }, { "500 Coin", false })
	v = PathView.build(p, 500, after)
	T.eq({ v.rows[2].changeText, v.rows[2].canChange }, { "500 Coin", true })
	T.eq({ v.rows[1].changeText, v.rows[1].canChange }, { "", false })
end)

T.test("max level and no calling", function()
	local p = make()
	p.xp.Mire = 19000
	T.eq(PathView.build(p, 0, 1000).rows[4].xpText, "MAX")
	local v = PathView.build(P.new(), 0, 1000)
	T.eq({ v.needsCalling, v.callingText }, { true, "Choose your Calling" })
	for _, row in v.rows do
		T.eq(row.rateText, "—")
		T.eq({ row.changeText, row.canChange, row.isCalling }, { "", false, false })
	end
end)
