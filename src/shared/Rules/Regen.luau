--!strict
-- Health that returns slowly once a fighter has been left alone. Pure. Every check is written so
-- that NaN refuses.
local Regen = {}

Regen.DELAY = 10
Regen.PER_SECOND = 1
Regen.MAX_STEP = 1

function Regen.step(
	health: number,
	maxHealth: number,
	lastHurtAt: number,
	now: number,
	dt: number
): number
	if
		health > 0
		and maxHealth > 0
		and maxHealth < math.huge
		and health < maxHealth
		and now - lastHurtAt >= Regen.DELAY
		and dt > 0
		and dt < math.huge
	then
		return math.min(maxHealth, health + Regen.PER_SECOND * math.min(dt, Regen.MAX_STEP))
	end
	return health
end

return Regen
