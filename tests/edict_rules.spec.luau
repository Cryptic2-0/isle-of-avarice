--!strict
local T = require("./harness")
local E = require("../src/shared/Rules/EdictRules")
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

-- Returns the given values in turn, then 0.
local function seq(...: number): () -> number
	local values = { ... }
	local i = 0
	return function()
		i += 1
		return values[i] or 0
	end
end

local function at(x: number, y: number, z: number): Types.Vec3
	return { x = x, y = y, z = z }
end

local ledger: Types.Ledger =
	{ claimed = { R009 = true }, free = { "R001", "E001", "E004", "E003" } }

T.test("constants", function()
	T.eq(
		{ E.VEIL_SECONDS, E.AUDIT_RANGE, E.MEET_RANGE, E.PASSAGE_DISTANCE, E.COMBAT_SECONDS },
		{ 600, 20, 30, 8, 30 }
	)
end)

T.test("parseUse: the card on that row must be the Edict the player saw", function()
	T.eq(
		{ E.parseUse(ledger, { freeIndex = 4, cardId = "E003" }) },
		{ { freeIndex = 4, cardId = "E003", key = "veil" }, "OK" } :: { any }
	)
	T.eq(
		{ E.parseUse(ledger, { freeIndex = 2, cardId = "E001", relicId = "R007" }) },
		{ { freeIndex = 2, cardId = "E001", key = "summons", relicId = "R007" }, "OK" } :: { any }
	)
	T.eq(
		{ E.parseUse(ledger, { freeIndex = 3, cardId = "E004", targetId = -2 }) },
		{ { freeIndex = 3, cardId = "E004", key = "passage", targetId = -2 }, "OK" } :: { any }
	)
	-- What an Edict does not need is dropped.
	T.eq(
		(E.parseUse(ledger, { freeIndex = 4, cardId = "E003", relicId = "R007", targetId = 5 })),
		{ freeIndex = 4, cardId = "E003", key = "veil" }
	)
end)

T.test("parseUse refuses hostile requests", function()
	T.eq(
		{ E.parseUse(nil, { freeIndex = 2, cardId = "E001" }) },
		{ nil, "DATA_NOT_LOADED" } :: { any }
	)
	for _, bad in { "x", 5, true } :: { any } do
		T.eq({ E.parseUse(ledger, bad) }, { nil, "BAD_REQUEST" } :: { any })
	end
	T.eq({ E.parseUse(ledger, nil) }, { nil, "BAD_REQUEST" } :: { any })
	local requests: { any } = {
		{ cardId = "E003" },
		{ freeIndex = "4", cardId = "E003" },
		{ freeIndex = 4 },
		{ freeIndex = 4, cardId = 3 },
		{ freeIndex = 4, cardId = string.rep("E", 40) },
		-- Summons without a Relic, or with something that is not one.
		{ freeIndex = 2, cardId = "E001" },
		{ freeIndex = 2, cardId = "E001", relicId = "E002" },
		{ freeIndex = 2, cardId = "E001", relicId = 7 },
		-- Passage without a player.
		{ freeIndex = 3, cardId = "E004" },
		{ freeIndex = 3, cardId = "E004", targetId = "2" },
		{ freeIndex = 3, cardId = "E004", targetId = 1.5 },
		{ freeIndex = 3, cardId = "E004", targetId = 0 / 0 },
		{ freeIndex = 3, cardId = "E004", targetId = math.huge },
	}
	for i, raw in requests do
		T.eq({ E.parseUse(ledger, raw) }, { nil, "BAD_REQUEST" } :: { any }, "request " .. i)
	end
	-- The row moved (a double click), or is out of range.
	for _, index in { 3, 0, 5, -1, 1.5, 0 / 0 } do
		T.eq(
			{ E.parseUse(ledger, { freeIndex = index, cardId = "E003" }) },
			{ nil, "BAD_INDEX" } :: { any }
		)
	end
	-- A Relic is not an Edict.
	T.eq(
		{ E.parseUse(ledger, { freeIndex = 1, cardId = "R001" }) },
		{ nil, "BAD_REQUEST" } :: { any }
	)
end)

T.test("canTravel: not while Marked, soon after a fight, or in a trial", function()
	local free = { marked = false, inTrial = false }
	T.eq({ E.canTravel(free, 100) }, { true })
	T.eq(
		{ E.canTravel({ marked = true, inTrial = true, lastFightAt = 99 }, 100) },
		{ false, "EDICT_MARKED" } :: { any }
	)
	T.eq(
		{ E.canTravel({ marked = false, inTrial = true, lastFightAt = 71 }, 100) },
		{ false, "EDICT_IN_COMBAT" } :: { any }
	)
	T.eq({ E.canTravel({ marked = false, inTrial = false, lastFightAt = 70 }, 100) }, { true })
	T.eq(
		{ E.canTravel({ marked = false, inTrial = false, lastFightAt = 70 }, 0 / 0) },
		{ false, "EDICT_IN_COMBAT" } :: { any },
		"a broken clock fails closed"
	)
	T.eq(
		{ E.canTravel({ marked = false, inTrial = true }, 100) },
		{ false, "EDICT_IN_TRIAL" } :: { any }
	)
end)

T.test("canDeal: not while Marked or soon after a fight, trial or not", function()
	T.eq({ E.canDeal({ marked = false }, 100) }, { true })
	T.eq(
		{ E.canDeal({ marked = true, lastFightAt = 99 }, 100) },
		{ false, "EDICT_MARKED" } :: { any }
	)
	T.eq(
		{ E.canDeal({ marked = false, lastFightAt = 71 }, 100) },
		{ false, "EDICT_IN_COMBAT" } :: { any }
	)
	T.eq({ E.canDeal({ marked = false, lastFightAt = 70 }, 100) }, { true })
	T.eq(
		{ E.canDeal({ marked = false, lastFightAt = 70 }, 0 / 0) },
		{ false, "EDICT_IN_COMBAT" } :: { any },
		"a broken clock fails closed"
	)
end)

T.test("Summons lists the others who hold the Relic, never the Veiled or the asker", function()
	local people: { E.Person } = {
		{
			userId = 1,
			name = "Zed",
			ledger = { claimed = { R007 = true }, free = {} },
			veiled = false,
		},
		{
			userId = 2,
			name = "Ann",
			ledger = { claimed = {}, free = { "R007", "R007" } },
			veiled = false,
		},
		{
			userId = 3,
			name = "Bob",
			ledger = { claimed = { R007 = true }, free = {} },
			veiled = true,
		},
		{
			userId = 4,
			name = "Cy",
			ledger = { claimed = { R001 = true }, free = { "E001" } },
			veiled = false,
		},
		{
			userId = 5,
			name = "Me",
			ledger = { claimed = { R007 = true }, free = {} },
			veiled = false,
		},
	}
	T.eq(E.holders(people, "R007", 5), { "Ann", "Zed" })
	T.eq(E.holders(people, "R001", 5), { "Cy" })
	T.eq(E.holders(people, "R030", 5), {})
	T.eq(E.holders(people, "nope", 5), {})
	T.eq(E.summonsResult("R007", { "Ann", "Zed" }), {
		title = "Summons: Bottled Squall",
		lines = { "Held on this server by:", "Ann", "Zed" },
	})
	T.eq(E.summonsResult("R007", {}), {
		title = "Summons: Bottled Squall",
		lines = { "Nobody else here holds it, or they are veiled." },
	})
end)

T.test("Audit picks the nearest other player within 20 studs", function()
	local me = { userId = 1, position = at(0, 3, 0) }
	local others = {
		{ userId = 1, position = at(0, 3, 0) },
		{ userId = 2, position = at(15, 3, 0) },
		{ userId = 3, position = at(0, 3, -9) },
		{ userId = 4, position = at(0, 3, 21) },
	}
	T.eq(E.auditTarget(me, others), 3)
	T.eq(E.auditTarget(me, { others[1], others[4] }), nil)
	T.eq(E.auditTarget(me, { { userId = 4, position = at(0, 3, 20) } }), 4, "inclusive at 20")
	T.eq(E.auditTarget(me, { { userId = 4, position = at(0, 23.1, 0) } }), nil, "height counts")
	T.eq(
		E.auditTarget(
			me,
			{ { userId = 9, position = at(5, 3, 0) }, { userId = 6, position = at(-5, 3, 0) } }
		),
		6
	)
	T.eq(E.auditTarget(me, { { userId = 4, position = at(0 / 0, 3, 0) } }), nil)
	T.eq(E.auditTarget(me, {}), nil)
end)

T.test("Audit shows claimed Relics, what is Vaulted, and the free slots", function()
	local seen: Types.Ledger =
		{ claimed = { R007 = true, R001 = true }, free = { "R001", "E003", "R001" } }
	T.eq(E.auditResult("Ann", seen, { R007 = true }), {
		title = "Audit: Ann",
		lines = {
			"Claimed: 2 of 30",
			"001 Tarnished Tally-Coin (Copper)",
			"007 Bottled Squall (Silver), Vaulted",
			"Free slots: 3 of 20",
			"Tarnished Tally-Coin x2",
			"Veil",
		},
	})
	T.eq(E.auditResult("Bob", { claimed = {}, free = {} }, {}), {
		title = "Audit: Bob",
		lines = { "Claimed: 0 of 30", "Free slots: 0 of 20" },
	})
	T.eq(E.veiledResult("Bob"), { title = "Audit: Bob", lines = { "Their Ledger is veiled." } })
end)

T.test("Veil runs until its time", function()
	T.eq(
		{ E.isVeiled(nil, 5), E.isVeiled(700, 699.9), E.isVeiled(700, 700) },
		{ false, true, false }
	)
	T.falsy(E.isVeiled(700, 0 / 0))
	T.falsy(E.isVeiled(0 / 0, 5))
	T.eq(E.veilSeconds(700, 100), 600)
	T.eq(
		{ E.veilSeconds(nil, 100), E.veilSeconds(50, 100), E.veilSeconds(0 / 0, 100) },
		{ 0, 0, 0 }
	)
end)

T.test("Passage sets the traveller down 8 studs away, on a clear spot", function()
	local target = at(100, 3, 50)
	T.eq(
		E.arrival(target, function()
			return true
		end),
		at(108, 3, 50)
	)
	-- The first ring spots are blocked: the next clear one is taken.
	local tried = 0
	local spot = E.arrival(target, function(_x, _z)
		tried += 1
		return tried == 3
	end)
	T.eq(tried, 3)
	T.truthy(math.abs(spot.x - 100) < 1e-6 and math.abs(spot.z - 58) < 1e-6)
	-- Every spot of the ring is 8 studs from the target.
	local ring: { number } = {}
	E.arrival(target, function(x, z)
		table.insert(ring, math.sqrt((x - 100) ^ 2 + (z - 50) ^ 2))
		return false
	end)
	T.eq(#ring, 8)
	for _, distance in ring do
		T.truthy(math.abs(distance - 8) < 1e-6)
	end
	-- Nowhere is clear: beside the target is still better than nothing.
	T.eq(
		E.arrival(target, function()
			return false
		end),
		target
	)
end)

T.test("defeat destroys a third of the Edicts, rounded down, chosen at random", function()
	local none, lostNone =
		E.defeatLoss({ claimed = { R001 = true }, free = { "R002", "E001", "E002" } }, seq())
	T.eq({ none.free, lostNone }, { { "R002", "E001", "E002" }, {} } :: { any })

	local three: Types.Ledger =
		{ claimed = { R001 = true }, free = { "E001", "R002", "E002", "E003" } }
	local first, lostFirst = E.defeatLoss(three, seq(0))
	T.eq({ first.free, lostFirst }, { { "R002", "E002", "E003" }, { "E001" } } :: { any })
	local last, lostLast = E.defeatLoss(three, seq(0.99))
	T.eq({ last.free, lostLast }, { { "E001", "R002", "E002" }, { "E003" } } :: { any })
	T.eq(last.claimed, { R001 = true })
	-- A roll of exactly 1, or junk, still picks a card.
	T.eq(#select(2, E.defeatLoss(three, seq(1))), 1)
	T.eq(#select(2, E.defeatLoss(three, seq(0 / 0))), 1)
	T.eq(#select(2, E.defeatLoss(three, seq(-3))), 1)

	local seven: Types.Ledger =
		{ claimed = {}, free = { "E001", "E002", "E003", "E004", "E005", "E001", "E002", "R001" } }
	local after, lost = E.defeatLoss(seven, seq(0.5, 0.5))
	T.eq(#lost, 2, "7 Edicts lose 2")
	T.eq(#after.free, 6)
	T.eq(lost, { "E004", "E005" })
	T.eq(after.free, { "E001", "E002", "E003", "E001", "E002", "R001" })
	-- Relics are never touched.
	local nine: Types.Ledger = { claimed = {}, free = {} }
	for _ = 1, 9 do
		table.insert(nine.free, "E005")
		table.insert(nine.free, "R003")
	end
	local kept, gone = E.defeatLoss(nine, math.random)
	T.eq(#gone, 3)
	local relics = 0
	for _, id in kept.free do
		if id == "R003" then
			relics += 1
		end
	end
	T.eq(relics, 9)
end)

T.test("near: within range in three dimensions", function()
	T.truthy(E.near(at(0, 0, 0), at(30, 0, 0), 30))
	T.falsy(E.near(at(0, 0, 0), at(30, 1, 0), 30))
	T.falsy(E.near(at(0, 0, 0), at(0 / 0, 0, 0), 30))
end)

T.test("no rule changes its arguments", function()
	local mine = copy(ledger)
	E.parseUse(mine, { freeIndex = 4, cardId = "E003" })
	E.defeatLoss(mine, seq(0.5))
	E.auditResult("x", mine, {})
	T.eq(mine, ledger)
end)
