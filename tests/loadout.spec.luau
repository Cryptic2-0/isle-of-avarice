--!strict
local T = require("./harness")
local Loadout = require("../src/shared/Rules/Loadout")
local P = require("../src/shared/Rules/PathProgress")

local function makeBase()
	local p = P.new()
	p.calling = "Fang"
	p.xp.Fang = 4500
	p.loadout = { "lunge", "", "", "" }
	return p
end
local base = makeBase()

T.test("apply equips, moves, and clears", function()
	T.eq(
		(Loadout.apply(base, { slot = 2, abilityId = "rending_flurry" }, true) :: any).loadout,
		{ "lunge", "rending_flurry", "", "" }
	)
	T.eq(
		(Loadout.apply(base, { slot = 3, abilityId = "lunge" }, true) :: any).loadout,
		{ "", "", "lunge", "" }
	)
	T.eq(
		(Loadout.apply(base, { slot = 1, abilityId = "" }, true) :: any).loadout,
		{ "", "", "", "" }
	)
	T.eq(
		select(2, Loadout.apply(base, { slot = 2, abilityId = "rending_flurry" }, true)),
		"LOADOUT_CHANGED"
	)
	T.eq(base.loadout, { "lunge", "", "", "" })
end)

T.test("apply failures", function()
	local function fail(progress: any, raw: any, safe: boolean, code: string)
		local result, got = Loadout.apply(progress, raw, safe)
		T.eq(result == nil, true)
		T.eq(got, code)
	end
	fail(base, { slot = 2, abilityId = "rending_flurry" }, false, "LOADOUT_SAFE_ZONE")
	fail(base, { slot = 2, abilityId = "final_toll" }, true, "NOT_UNLOCKED")
	fail(P.new(), { slot = 1, abilityId = "" }, true, "NO_CALLING")
	fail(nil, { slot = 1, abilityId = "" }, true, "DATA_NOT_LOADED")
	local bad: { any } = {
		5,
		"x",
		{},
		{ slot = 0, abilityId = "" },
		{ slot = 5, abilityId = "" },
		{ slot = 1.5, abilityId = "" },
		{ slot = 0 / 0, abilityId = "" },
		{ slot = "1", abilityId = "" },
		{ slot = 1 },
		{ slot = 1, abilityId = 7 },
		{ slot = 1, abilityId = string.rep("a", 17) },
		{ slot = 1, abilityId = "nope" },
	}
	for _, raw in bad do
		fail(base, raw, true, "BAD_REQUEST")
	end
	-- nil is skipped in array literals, so test it separately
	fail(base, nil, true, "BAD_REQUEST")
end)

T.test("autoFill", function()
	T.eq(
		Loadout.autoFill(base, { "rending_flurry" }).loadout,
		{ "lunge", "rending_flurry", "", "" }
	)
	T.eq(Loadout.autoFill(base, { "lunge" }).loadout, { "lunge", "", "", "" })
	local full = makeBase()
	full.loadout = { "a", "b", "c", "d" }
	T.eq(Loadout.autoFill(full, { "lunge" }).loadout, { "a", "b", "c", "d" })
	T.eq(Loadout.autoFill(base, { "x", "y", "z", "w" }).loadout, { "lunge", "x", "y", "z" })
	T.eq(base.loadout, { "lunge", "", "", "" })
end)
