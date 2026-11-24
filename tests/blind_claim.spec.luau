--!strict
local T = require("./harness")
local BlindClaim = require("../src/shared/Rules/BlindClaim")
local Ledger = require("../src/shared/Rules/Ledger")
local Relics = require("../src/shared/Catalog/Relics")

local function fresh(): (any, any)
	return { claimed = { R001 = true, R007 = true, R012 = true }, free = { "R007", "R002" } }, {
		claimed = {},
		free = {},
	}
end

local function code(...: any): any
	return (select(4, ...))
end

T.test("start opens a 5-pick, 30-second claim", function()
	T.eq(
		BlindClaim.start(100),
		{ picksLeft = 5, expiresAt = 130, taken = {}, picked = {}, takenIds = {} }
	)
	local c0 = BlindClaim.start(100)
	T.truthy(BlindClaim.isOpen(c0, 129))
	T.falsy(BlindClaim.isOpen(c0, 130))
	T.eq(BlindClaim.TIER_LIMIT, { Crown = 1, Platinum = 1, Gold = 2, Silver = 3, Copper = 3 })
end)

T.test("a spare is taken before the claimed copy", function()
	local victim, killer = fresh()
	local c0 = BlindClaim.start(100)
	local c1, v1, k1, code1, id1 = BlindClaim.pick(c0, victim, {}, killer, 7, 101)
	T.eq({ code1, id1 }, { "TAKEN", "R007" })
	T.eq(v1, { claimed = { R001 = true, R007 = true, R012 = true }, free = { "R002" } })
	T.eq(k1, { claimed = {}, free = { "R007" } })
	T.eq(c1, {
		picksLeft = 4,
		expiresAt = 130,
		taken = { Silver = 1 },
		picked = { ["7"] = "TAKEN" },
		takenIds = { "R007" },
	})
end)

T.test("the claimed copy is taken when there is no spare", function()
	local victim, killer = fresh()
	local _, v2, k2, code2 = BlindClaim.pick(BlindClaim.start(100), victim, {}, killer, 1, 101)
	T.eq(code2, "TAKEN")
	T.eq(v2.claimed.R001, nil)
	T.eq(k2.free, { "R001" })
end)

T.test("misses spend a pick and change nothing", function()
	local victim, killer = fresh()
	local c0 = BlindClaim.start(100)
	local c3, v3, k3, code3, id3 = BlindClaim.pick(c0, victim, {}, killer, 3, 101)
	T.eq({ code3, id3, c3.picksLeft, c3.picked["3"] }, { "MISS", nil, 4, "MISS" })
	T.eq(v3, victim)
	T.eq(k3, killer)
	T.eq(code(BlindClaim.pick(c0, victim, { R012 = true }, killer, 12, 101)), "MISS")
	local cv = BlindClaim.pick(c0, victim, { R012 = true }, killer, 12, 101)
	T.eq(cv.picksLeft, 4)
end)

T.test("a killer with full free slots gets a miss and the victim keeps the card", function()
	local victim, _ = fresh()
	local full: any = { claimed = {}, free = {} }
	for _ = 1, Ledger.FREE_SLOTS do
		table.insert(full.free, "R003")
	end
	local c, v, k, cd = BlindClaim.pick(BlindClaim.start(100), victim, {}, full, 1, 101)
	T.eq(cd, "MISS")
	T.eq(c.picksLeft, 4)
	T.eq(v, victim)
	T.eq(k, full)
end)

T.test("bad slots are refused and spend nothing", function()
	local victim, killer = fresh()
	local c0 = BlindClaim.start(100)
	for _, bad in { 0, 13, 1.5, -1, 0 / 0, math.huge, -math.huge, "7", true, {} } do
		local c, v, k, cd = BlindClaim.pick(c0, victim, {}, killer, bad, 101)
		T.eq(cd, "BAD_SLOT", tostring(bad))
		T.eq(c, c0)
		T.eq(v, victim)
		T.eq(k, killer)
	end
	T.eq(code(BlindClaim.pick(c0, victim, {}, killer, nil, 101)), "BAD_SLOT")
end)

T.test("repeat slot and expiry are refused and spend nothing", function()
	local victim, killer = fresh()
	local c0 = BlindClaim.start(100)
	local c1, v1, k1 = BlindClaim.pick(c0, victim, {}, killer, 7, 101)
	local c, v, k, cd = BlindClaim.pick(c1, v1, {}, k1, 7, 102)
	T.eq(cd, "ALREADY_PICKED")
	T.eq(c, c1)
	T.eq(v, v1)
	T.eq(k, k1)
	local ce, _, _, cde = BlindClaim.pick(c0, victim, {}, killer, 7, 130)
	T.eq(cde, "CLAIM_OVER")
	T.eq(ce, c0)
end)

T.test("after 5 picks every further pick is CLAIM_OVER", function()
	local victim, killer = fresh()
	local c: any, v: any, k: any = BlindClaim.start(100), victim, killer
	for slot = 1, 5 do
		c, v, k = BlindClaim.pick(c, v, {}, k, slot, 101)
	end
	T.eq(c.picksLeft, 0)
	T.falsy(BlindClaim.isOpen(c, 101))
	local c2, _, _, cd = BlindClaim.pick(c, v, {}, k, 6, 102)
	T.eq(cd, "CLAIM_OVER")
	T.eq(c2, c)
end)

T.test("tier limit refuses and spends nothing", function()
	local victim, killer = fresh()
	local c0: any = BlindClaim.start(100)
	c0.taken = { Gold = 2 }
	local snapshot =
		{ picksLeft = 5, expiresAt = 130, taken = { Gold = 2 }, picked = {}, takenIds = {} }
	local c, v, k, cd = BlindClaim.pick(c0, victim, {}, killer, 10, 101)
	T.eq(cd, "TIER_LIMIT")
	T.eq(c, snapshot)
	T.eq(v, victim)
	T.eq(k, killer)
end)

T.test("inputs are never mutated", function()
	local victim, killer = fresh()
	local c0 = BlindClaim.start(100)
	local vault = { R012 = true }
	for slot = 0, 13 do
		BlindClaim.pick(c0, victim, vault, killer, slot, 101)
	end
	local v2, k2 = fresh()
	T.eq(victim, v2)
	T.eq(killer, k2)
	T.eq(c0, BlindClaim.start(100))
	T.eq(vault, { R012 = true })
end)

T.test("every pick conserves the total copies of every Relic", function()
	for _, vault in { {}, { R007 = true } } do
		for firstSlot = 1, Relics.count do
			local victim, killer = fresh()
			local c: any, v: any, k: any = BlindClaim.start(100), victim, killer
			local before: { [string]: number } = {}
			for _, relic in Relics.list do
				before[relic.id] = Ledger.count(victim, relic.id) + Ledger.count(killer, relic.id)
			end
			for i = 0, 4 do
				local slot = (firstSlot - 1 + i * 3) % Relics.count + 1
				c, v, k = BlindClaim.pick(c, v, vault, k, slot, 101)
				for _, relic in Relics.list do
					T.eq(
						Ledger.count(v, relic.id) + Ledger.count(k, relic.id),
						before[relic.id],
						`{relic.id} after pick {i + 1}`
					)
				end
			end
		end
	end
end)
