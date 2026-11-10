--!strict
local T = require("./harness")
local Ledger = require("../src/shared/Rules/Ledger")
local Sources = require("../src/shared/Rules/Sources")
local Types = require("../src/shared/Types")

local cache: Types.Cache = { id = "C007", relicId = "R007", position = { x = 0, y = 0, z = 0 } } -- Silver: 120 s

T.test("new makes every cache available at time 0", function()
	local s0 = Sources.new({ cache })
	T.truthy(Sources.isAvailable(s0, "C007", 0))
	T.falsy(Sources.isAvailable(s0, "C999", 0), "unknown cache")
	T.eq(Sources.MAX_DISTANCE, 15)
end)

T.test("collect gives the card and starts the tier respawn", function()
	local s0 = Sources.new({ cache })
	local s1, l1, code1 = Sources.tryCollect(s0, Ledger.new(), cache, 100, 10)
	T.eq(code1, "GOT_CARD")
	T.eq(l1, { claimed = {}, free = { "R007" } })
	T.falsy(Sources.isAvailable(s1, "C007", 219))
	T.truthy(Sources.isAvailable(s1, "C007", 220))
	T.truthy(Sources.isAvailable(s0, "C007", 100), "input state not mutated")
end)

T.test("a second player at the same instant gets CACHE_EMPTY", function()
	local s0 = Sources.new({ cache })
	local s1 = Sources.tryCollect(s0, Ledger.new(), cache, 100, 10)
	local s2, l2, code2 = Sources.tryCollect(s1, Ledger.new(), cache, 100, 10)
	T.eq({ l2, code2 }, { nil, "CACHE_EMPTY" })
	T.eq(s2, s1)
end)

T.test("full free slots do not consume the cache", function()
	local s0 = Sources.new({ cache })
	local free = {}
	for _ = 1, Ledger.FREE_SLOTS do
		table.insert(free, "R001")
	end
	local s1, l1, code = Sources.tryCollect(s0, { claimed = {}, free = free }, cache, 100, 10)
	T.eq({ l1, code }, { nil, "FREE_FULL" })
	T.eq(s1, s0)
	T.truthy(Sources.isAvailable(s1, "C007", 100))
end)

T.test("distance limit is inclusive at 15", function()
	local s0 = Sources.new({ cache })
	local sFar, lFar, codeFar = Sources.tryCollect(s0, Ledger.new(), cache, 0, 15.01)
	T.eq({ lFar, codeFar }, { nil, "TOO_FAR" })
	T.eq(sFar, s0)
	local _, _, codeOk = Sources.tryCollect(s0, Ledger.new(), cache, 0, 15)
	T.eq(codeOk, "GOT_CARD")
	local _, _, codeNan = Sources.tryCollect(s0, Ledger.new(), cache, 0, 0 / 0)
	T.eq(codeNan, "TOO_FAR")
end)

T.test("check order: data, distance, cache, free", function()
	local s0 = Sources.new({ cache })
	local _, l, code = Sources.tryCollect(s0, nil, cache, 0, 999)
	T.eq({ l, code }, { nil, "DATA_NOT_LOADED" })
	local taken = Sources.tryCollect(s0, Ledger.new(), cache, 0, 1)
	local _, _, farAndEmpty = Sources.tryCollect(taken, Ledger.new(), cache, 0, 999)
	T.eq(farAndEmpty, "TOO_FAR")
end)

T.test("unknown cache id is CACHE_EMPTY", function()
	local s0 = Sources.new({ cache })
	local other: Types.Cache = { id = "C999", relicId = "R001", position = { x = 0, y = 0, z = 0 } }
	local s1, l, code = Sources.tryCollect(s0, Ledger.new(), other, 0, 1)
	T.eq({ l, code }, { nil, "CACHE_EMPTY" })
	T.eq(s1, s0)
end)
