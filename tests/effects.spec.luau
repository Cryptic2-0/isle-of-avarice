--!strict
local T = require("./harness")
local Effects = require("../src/shared/Rules/Effects")

T.test("damage resolution: plain, immune, reduction, shield, reflect, bad amounts", function()
	local s0 = Effects.new()
	T.eq({ select(2, Effects.resolveDamage(s0, 20, 0)) }, { 20, 0 })
	local imm = Effects.applyImmune(s0, 1.5, 0)
	T.eq({ select(2, Effects.resolveDamage(imm, 20, 1)) }, { 0, 0 })
	T.eq({ select(2, Effects.resolveDamage(imm, 20, 1.5)) }, { 20, 0 })
	T.truthy(Effects.isImmune(imm, 1))
	T.falsy(Effects.isImmune(imm, 1.5))
	local red = Effects.applyReduction(s0, 0.6, 2, 0)
	T.eq(select(2, Effects.resolveDamage(red, 20, 1)), 12)
	T.eq(select(2, Effects.resolveDamage(red, 20, 2)), 20)
	local shielded = Effects.applyShield(red, 30, 6, 0)
	local s1, h1 = Effects.resolveDamage(shielded, 20, 1) -- 12 after reduction, all absorbed
	T.eq({ h1, s1.shield }, { 0, 18 })
	local _, h2 = Effects.resolveDamage(s1, 40, 1.5) -- 24 after reduction, 18 absorbed
	T.eq(h2, 6)
	T.eq(select(2, Effects.resolveDamage(Effects.applyShield(s0, 30, 6, 0), 20, 6)), 20)
	local refl = Effects.applyReflect(red, 0.5, 2, 0)
	T.eq({ select(2, Effects.resolveDamage(refl, 20, 1)) }, { 12, 6 })
	for _, bad in { 0, -5, 0 / 0, math.huge } do
		T.eq({ select(2, Effects.resolveDamage(s0, bad, 0)) }, { 0, 0 })
	end
	T.eq(
		{ select(2, Effects.resolveDamage(shielded, 20, 0 / 0)) },
		{ 20, 0 },
		"NaN now: nothing active"
	)
end)

T.test("slow and root", function()
	local s0 = Effects.new()
	local slow = Effects.applySlow(s0, 0.5, 4, 0)
	T.eq({ Effects.speedFactor(slow, 1), Effects.speedFactor(slow, 4) }, { 0.5, 1 })
	T.eq(Effects.speedFactor(Effects.applySlow(slow, 0.7, 10, 1), 2), 0.5)
	T.eq(Effects.speedFactor(Effects.applySlow(slow, 0.7, 10, 1), 5), 1)
	T.eq(Effects.speedFactor(Effects.applySlow(slow, 0.3, 1, 1), 1.5), 0.3)
	T.eq(Effects.speedFactor(Effects.applySlow(slow, 0.5, 10, 1), 5), 0.5, "equal refreshes")
	T.eq(
		Effects.speedFactor(Effects.applySlow(slow, 0.7, 10, 4), 5),
		0.7,
		"expired slow is replaced"
	)
	local rooted = Effects.applyRoot(slow, 1.5, 0)
	T.eq({
		Effects.speedFactor(rooted, 1),
		Effects.speedFactor(rooted, 1.5),
		Effects.isRooted(rooted, 1),
	}, { 0, 0.5, true })
	T.falsy(Effects.isRooted(rooted, 1.5))
end)

T.test("ambient slow: skips the immune, never cuts a slow short", function()
	local s0 = Effects.new()

	-- An immune player is not slowed at all.
	local imm = Effects.applyImmune(s0, 5, 0)
	T.eq(Effects.applyAmbientSlow(imm, 0.6, 1, 1), imm)
	T.eq(Effects.speedFactor(Effects.applyAmbientSlow(imm, 0.6, 1, 1), 1.5), 1)
	-- Once the immunity has ended the slow lands.
	T.eq(Effects.applyAmbientSlow(imm, 0.6, 1, 5), Effects.applySlow(imm, 0.6, 1, 5))

	-- With no slow in effect it is the plain slow.
	T.eq(Effects.applyAmbientSlow(s0, 0.6, 1, 1), Effects.applySlow(s0, 0.6, 1, 1))
	local expired = Effects.applySlow(s0, 0.4, 1, 0)
	T.eq(Effects.applyAmbientSlow(expired, 0.6, 1, 2), Effects.applySlow(expired, 0.6, 1, 2))

	-- A stronger slow that lasts longer is left alone (an ability's slow, say).
	local undertow = Effects.applySlow(s0, 0.4, 5, 0)
	T.eq(Effects.applyAmbientSlow(undertow, 0.6, 1, 1), undertow)
	-- So is an equal one that lasts longer: the bog must not shorten it.
	local equalLonger = Effects.applySlow(s0, 0.6, 5, 0)
	T.eq(Effects.applyAmbientSlow(equalLonger, 0.6, 1, 1), equalLonger)
	T.eq(Effects.applyAmbientSlow(equalLonger, 0.6, 1, 1).slowUntil, 5)

	-- A weaker slow in effect gives way to the ambient one.
	local weaker = Effects.applySlow(s0, 0.8, 5, 0)
	local over = Effects.applyAmbientSlow(weaker, 0.6, 1, 1)
	T.eq(over, Effects.applySlow(weaker, 0.6, 1, 1))
	T.eq({ over.slowFactor, over.slowUntil }, { 0.6, 2 })

	-- An equal slow that ends sooner is refreshed.
	local equalSooner = Effects.applySlow(s0, 0.6, 1.5, 0)
	local refreshed = Effects.applyAmbientSlow(equalSooner, 0.6, 1, 1)
	T.eq(refreshed, Effects.applySlow(equalSooner, 0.6, 1, 1))
	T.eq({ refreshed.slowFactor, refreshed.slowUntil }, { 0.6, 2 })

	-- The status passed in is never changed.
	local before = table.clone(weaker)
	Effects.applyAmbientSlow(weaker, 0.6, 1, 1)
	T.eq(weaker, before)
end)

T.test("burn and cleanse", function()
	local s0 = Effects.new()
	local slow = Effects.applySlow(s0, 0.5, 4, 0)
	local burning = Effects.applyBurn(s0, 3, 3, 7, 0)
	T.eq({ Effects.burnTick(burning, 2.9) }, { 3, 7 })
	T.eq({ Effects.burnTick(burning, 3) }, { 0, 0 })
	local clean = Effects.cleanse(Effects.applyRoot(Effects.applyBurn(slow, 3, 3, 7, 0), 1.5, 0))
	T.eq({ Effects.speedFactor(clean, 0.5), Effects.burnTick(clean, 0.5) }, { 1, 0, 0 })
end)

T.test("taunt and empower", function()
	local s0 = Effects.new()
	local taunted = Effects.applyTaunt(s0, 7, 3, 0)
	T.eq(Effects.tauntedBy(taunted, 2.9), 7)
	T.eq(Effects.tauntedBy(taunted, 3), nil)
	T.eq(Effects.tauntedBy(s0, 0), nil)
	local emp = Effects.applyEmpower(s0, 20, 4, 0)
	local emp2, bonus = Effects.takeEmpower(emp, 3.9)
	T.eq(
		{ bonus, select(2, Effects.takeEmpower(emp2, 3.9)), select(2, Effects.takeEmpower(emp, 4)) },
		{ 20, 0, 0 }
	)
	T.eq(select(2, Effects.takeEmpower(emp, 0 / 0)), 0)
end)

T.test("no function mutates the status passed in", function()
	local s0 = Effects.new()
	T.eq(s0.reduceFactor, 1)
	T.eq(s0.slowFactor, 1)
	T.eq(s0.reflectFactor, 1)
	local before = table.clone(s0)
	Effects.applyImmune(s0, 1, 0)
	Effects.applyReduction(s0, 0.5, 1, 0)
	Effects.applyShield(s0, 5, 1, 0)
	Effects.applyReflect(s0, 0.5, 1, 0)
	Effects.applySlow(s0, 0.5, 1, 0)
	Effects.applyRoot(s0, 1, 0)
	Effects.applyBurn(s0, 1, 1, 2, 0)
	Effects.applyTaunt(s0, 2, 1, 0)
	Effects.applyEmpower(s0, 5, 1, 0)
	Effects.cleanse(s0)
	T.eq(s0, before)
	local busy = Effects.applyShield(Effects.applyEmpower(s0, 5, 9, 0), 10, 9, 0)
	local busyBefore = table.clone(busy)
	Effects.resolveDamage(busy, 4, 1)
	Effects.takeEmpower(busy, 1)
	Effects.applySlow(busy, 0.1, 5, 1)
	T.eq(busy, busyBefore)
end)
