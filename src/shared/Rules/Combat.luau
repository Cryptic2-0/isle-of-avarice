--!strict
local Types = require("../Types")

type Vec3 = Types.Vec3

export type Fighter = { id: number, position: Vec3, look: Vec3 }
-- key: tostring(victim id)
export type HitLog = { [string]: { attackerId: number, at: number } }

local Combat = {}

Combat.MAX_HEALTH = 100
Combat.STRIKE_DAMAGE = 20
Combat.STRIKE_COOLDOWN = 0.8
Combat.STRIKE_RANGE = 8
Combat.STRIKE_MIN_DOT = 0.5 -- target must be within 60 degrees of straight ahead
Combat.STRIKE_MAX_HEIGHT = 6 -- maximum vertical gap
Combat.KILL_CREDIT_SECONDS = 15
Combat.COMBAT_LOG_SECONDS = 30

function Combat.canStrike(lastStrikeAt: number?, now: number): boolean
	return lastStrikeAt == nil or now - lastStrikeAt >= Combat.STRIKE_COOLDOWN
end

-- Distance and direction ignore the y axis. Returns the id of the nearest fighter in reach and arc.
function Combat.pickTarget(attacker: Fighter, others: { Fighter }): number?
	local lookLength =
		math.sqrt(attacker.look.x * attacker.look.x + attacker.look.z * attacker.look.z)
	if lookLength == 0 then
		return nil
	end
	local lookX = attacker.look.x / lookLength
	local lookZ = attacker.look.z / lookLength

	local bestId: number? = nil
	local bestDistance = math.huge
	for _, other in others do
		if other.id == attacker.id then
			continue
		end
		if math.abs(other.position.y - attacker.position.y) > Combat.STRIKE_MAX_HEIGHT then
			continue
		end
		local dx = other.position.x - attacker.position.x
		local dz = other.position.z - attacker.position.z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance > Combat.STRIKE_RANGE then
			continue
		end
		-- Standing on the attacker counts as in the arc.
		if distance > 0 and (dx * lookX + dz * lookZ) / distance < Combat.STRIKE_MIN_DOT then
			continue
		end
		if distance < bestDistance then
			bestDistance = distance
			bestId = other.id
		end
	end
	return bestId
end

function Combat.recordHit(log: HitLog, victimId: number, attackerId: number, now: number): HitLog
	local newLog = table.clone(log)
	newLog[tostring(victimId)] = { attackerId = attackerId, at = now }
	return newLog
end

function Combat.creditFor(
	log: HitLog,
	victimId: number,
	now: number,
	windowSeconds: number
): number?
	local entry = log[tostring(victimId)]
	if entry ~= nil and now - entry.at <= windowSeconds then
		return entry.attackerId
	end
	return nil
end

function Combat.clear(log: HitLog, victimId: number): HitLog
	local newLog = table.clone(log)
	newLog[tostring(victimId)] = nil
	return newLog
end

return Combat
