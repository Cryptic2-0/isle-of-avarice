--!strict
local T = require("./harness")
local Combat = require("../src/shared/Rules/Combat")
local Protection = require("../src/shared/Rules/Protection")

local function st(over: { [string]: any }?): Protection.Status
	local s: { [string]: any } =
		{ inSafeZone = false, newShield = false, respawnShieldUntil = 0, markedUntil = 0 }
	for k, v in over or {} do
		s[k] = v
	end
	return s :: any
end

T.test("inSafeZone uses horizontal distance from the origin", function()
	T.truthy(Protection.inSafeZone({ x = 40, y = 99, z = 0 }))
	T.falsy(Protection.inSafeZone({ x = 40.1, y = 0, z = 0 }))
	T.truthy(Protection.inSafeZone({ x = 28, y = 0, z = 28 }), "39.6 from the origin")
end)

T.test("canDamage shield rules", function()
	T.eq({ Protection.canDamage(st(), st(), 100) }, { true })
	T.eq({ Protection.canDamage(st({ newShield = true }), st(), 100) }, { false, "SHIELD_SELF" })
	T.eq(
		{ Protection.canDamage(st(), st({ newShield = true }), 100) },
		{ false, "TARGET_SHIELDED" }
	)
	T.eq(
		{ Protection.canDamage(st(), st({ respawnShieldUntil = 101 }), 100) },
		{ false, "TARGET_SHIELDED" }
	)
	T.eq({ Protection.canDamage(st(), st({ respawnShieldUntil = 100 }), 100) }, { true })
	T.eq({ Protection.canDamage(st({ respawnShieldUntil = 150 }), st(), 100) }, { true })
end)

T.test("canDamage safe zone edge, both directions", function()
	T.eq({ Protection.canDamage(st(), st({ inSafeZone = true }), 100) }, { false, "SAFE_ZONE" })
	T.eq({ Protection.canDamage(st({ inSafeZone = true }), st(), 100) }, { false, "SAFE_ZONE" })
end)

T.test("a Marked player gets no protection from the safe zone", function()
	T.eq(
		{ Protection.canDamage(st(), st({ inSafeZone = true, markedUntil = 200 }), 100) },
		{ true }
	)
	T.eq({
		Protection.canDamage(
			st({ inSafeZone = true }),
			st({ inSafeZone = true, markedUntil = 200 }),
			100
		),
	}, { true })
	T.eq({
		Protection.canDamage(
			st({ inSafeZone = true, markedUntil = 200 }),
			st({ inSafeZone = true }),
			100
		),
	}, { false, "SAFE_ZONE" })
end)

T.test("spares count toward ending the shield", function()
	T.falsy(Protection.shouldEndShield({ claimed = { R001 = true }, free = { "R002" } }))
	T.truthy(Protection.shouldEndShield({ claimed = {}, free = { "R001", "R001", "R001" } }))
	T.truthy(
		Protection.shouldEndShield({ claimed = { R001 = true, R002 = true }, free = { "R003" } })
	)
end)

T.test("isAggressor", function()
	local log = Combat.recordHit({}, 1, 2, 100) -- player 2 hit player 1 at t=100
	T.falsy(Protection.isAggressor(log, 1, 2, false, 120), "1 hits back within 30 s")
	T.truthy(Protection.isAggressor(log, 1, 2, false, 130.1))
	T.truthy(Protection.isAggressor(log, 3, 2, false, 101), "a third player joining in")
	T.falsy(Protection.isAggressor({}, 1, 2, true, 100), "attacking a Marked player")
end)

T.test("claim cooldown", function()
	local h = Protection.recordClaim({}, 1, 2, 1000)
	T.falsy(Protection.canClaim(h, 1, 2, 4599))
	T.truthy(Protection.canClaim(h, 1, 2, 4600))
	T.truthy(Protection.canClaim(h, 2, 1, 1001))
	T.truthy(Protection.canClaim(h, 1, 3, 1001))
	T.truthy(Protection.canClaim({}, 1, 2, 0))
end)

T.test("inSafeZone fails closed on NaN and treats infinity as outside", function()
	T.truthy(Protection.inSafeZone({ x = 0 / 0, y = 0, z = 0 }))
	T.truthy(Protection.inSafeZone({ x = 0, y = 0, z = 0 / 0 }))
	T.falsy(Protection.inSafeZone({ x = math.huge, y = 0, z = 0 }))
end)

T.test("NaN time keeps a shielded victim shielded and a safe-zone victim protected", function()
	T.eq(
		{ Protection.canDamage(st(), st({ respawnShieldUntil = 100 }), 0 / 0) },
		{ false, "TARGET_SHIELDED" }
	)
	T.eq(
		{ Protection.canDamage(st(), st({ inSafeZone = true, markedUntil = 0 / 0 }), 100) },
		{ false, "SAFE_ZONE" }
	)
end)

T.test("isMarked and isShielded boundaries", function()
	T.truthy(Protection.isMarked(st({ markedUntil = 101 }), 100))
	T.falsy(Protection.isMarked(st({ markedUntil = 100 }), 100))
	T.falsy(Protection.isMarked(st(), 100))
	T.truthy(Protection.isShielded(st({ respawnShieldUntil = 101 }), 100))
	T.falsy(Protection.isShielded(st({ respawnShieldUntil = 100 }), 100))
	T.truthy(Protection.isShielded(st({ newShield = true }), 100))
	T.falsy(Protection.isShielded(st(), 100))
end)

T.test("expired Marked status gives no exposure in the safe zone", function()
	T.eq(
		{ Protection.canDamage(st(), st({ inSafeZone = true, markedUntil = 100 }), 100) },
		{ false, "SAFE_ZONE" }
	)
	T.eq(
		{ Protection.canDamage(st(), st({ inSafeZone = true, markedUntil = 50 }), 100) },
		{ false, "SAFE_ZONE" }
	)
end)

T.test("isAggressor retaliation window boundary", function()
	local log = Combat.recordHit({}, 1, 2, 100)
	T.falsy(Protection.isAggressor(log, 1, 2, false, 130), "exactly 30 s after being hit")
	T.truthy(Protection.isAggressor(log, 1, 2, false, 130.1))
end)

T.test("recordClaim does not mutate its input", function()
	local h = Protection.recordClaim({}, 1, 2, 1000)
	local h2 = Protection.recordClaim(h, 3, 4, 2000)
	T.eq(h, { ["1:2"] = 1000 })
	T.eq(h2, { ["1:2"] = 1000, ["3:4"] = 2000 })
end)
