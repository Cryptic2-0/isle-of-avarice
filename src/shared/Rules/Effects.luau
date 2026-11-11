--!strict
-- Pure status-effect rules. Every "until" is exclusive: active while now < until.
-- Comparisons are written so a NaN time reads as "not active" and never grants anything.
export type Status = {
	immuneUntil: number,
	reduceUntil: number,
	reduceFactor: number,
	shield: number,
	shieldUntil: number,
	reflectUntil: number,
	reflectFactor: number,
	slowUntil: number,
	slowFactor: number,
	rootUntil: number,
	burnUntil: number,
	burnDps: number,
	burnBy: number,
	tauntUntil: number,
	tauntBy: number,
	empowerUntil: number,
	empowerBonus: number,
}

local Effects = {}

function Effects.new(): Status
	return {
		immuneUntil = 0,
		reduceUntil = 0,
		reduceFactor = 1,
		shield = 0,
		shieldUntil = 0,
		reflectUntil = 0,
		reflectFactor = 1,
		slowUntil = 0,
		slowFactor = 1,
		rootUntil = 0,
		burnUntil = 0,
		burnDps = 0,
		burnBy = 0,
		tauntUntil = 0,
		tauntBy = 0,
		empowerUntil = 0,
		empowerBonus = 0,
	}
end

function Effects.isImmune(s: Status, now: number): boolean
	return now < s.immuneUntil
end

function Effects.resolveDamage(s: Status, amount: number, now: number): (Status, number, number)
	-- Written positively so NaN, zero, negative and infinite amounts all fall out as no damage.
	if not (amount > 0 and amount < math.huge) then
		return s, 0, 0
	end
	if now < s.immuneUntil then
		return s, 0, 0
	end
	local after = amount
	if now < s.reduceUntil then
		after = amount * s.reduceFactor
	end
	local reflected = 0
	if now < s.reflectUntil then
		reflected = after * s.reflectFactor
	end
	local health = after
	local out = s
	if now < s.shieldUntil and s.shield > 0 then
		local absorbed = math.min(after, s.shield)
		health = after - absorbed
		out = table.clone(s)
		out.shield = s.shield - absorbed
	end
	-- A NaN factor would poison the result; fail to zero rather than to extra damage.
	if not (health >= 0) then
		health = 0
	end
	if not (reflected >= 0) then
		reflected = 0
	end
	return out, health, reflected
end

function Effects.applyImmune(s: Status, duration: number, now: number): Status
	local out = table.clone(s)
	out.immuneUntil = now + duration
	return out
end

function Effects.applyReduction(s: Status, factor: number, duration: number, now: number): Status
	local out = table.clone(s)
	out.reduceFactor = factor
	out.reduceUntil = now + duration
	return out
end

-- Replaces any current shield.
function Effects.applyShield(s: Status, amount: number, duration: number, now: number): Status
	local out = table.clone(s)
	out.shield = amount
	out.shieldUntil = now + duration
	return out
end

function Effects.applyReflect(s: Status, factor: number, duration: number, now: number): Status
	local out = table.clone(s)
	out.reflectFactor = factor
	out.reflectUntil = now + duration
	return out
end

-- Strongest (lowest factor) slow wins. An equal or stronger one replaces and refreshes;
-- a weaker one neither replaces nor extends the active slow.
function Effects.applySlow(s: Status, factor: number, duration: number, now: number): Status
	local out = table.clone(s)
	-- A NaN factor is rejected (it would otherwise read as stronger than anything).
	if not (factor >= 0) then
		return out
	end
	if now < s.slowUntil and not (factor <= s.slowFactor) then
		return out
	end
	out.slowFactor = factor
	out.slowUntil = now + duration
	return out
end

function Effects.applyRoot(s: Status, duration: number, now: number): Status
	local out = table.clone(s)
	out.rootUntil = now + duration
	return out
end

function Effects.applyBurn(
	s: Status,
	dps: number,
	duration: number,
	byId: number,
	now: number
): Status
	local out = table.clone(s)
	out.burnDps = dps
	out.burnBy = byId
	out.burnUntil = now + duration
	return out
end

function Effects.applyTaunt(s: Status, byId: number, duration: number, now: number): Status
	local out = table.clone(s)
	out.tauntBy = byId
	out.tauntUntil = now + duration
	return out
end

function Effects.applyEmpower(s: Status, bonus: number, duration: number, now: number): Status
	local out = table.clone(s)
	out.empowerBonus = bonus
	out.empowerUntil = now + duration
	return out
end

-- Clears slow, root and burn.
function Effects.cleanse(s: Status): Status
	local out = table.clone(s)
	out.slowUntil = 0
	out.slowFactor = 1
	out.rootUntil = 0
	out.burnUntil = 0
	out.burnDps = 0
	out.burnBy = 0
	return out
end

function Effects.isRooted(s: Status, now: number): boolean
	return now < s.rootUntil
end

function Effects.speedFactor(s: Status, now: number): number
	if now < s.rootUntil then
		return 0
	end
	if now < s.slowUntil then
		return s.slowFactor
	end
	return 1
end

function Effects.burnTick(s: Status, now: number): (number, number)
	if now < s.burnUntil then
		return s.burnDps, s.burnBy
	end
	return 0, 0
end

function Effects.tauntedBy(s: Status, now: number): number?
	if now < s.tauntUntil then
		return s.tauntBy
	end
	return nil
end

-- Returns the bonus while active and consumes it.
function Effects.takeEmpower(s: Status, now: number): (Status, number)
	if now < s.empowerUntil then
		local out = table.clone(s)
		out.empowerUntil = 0
		out.empowerBonus = 0
		return out, s.empowerBonus
	end
	return s, 0
end

return Effects
