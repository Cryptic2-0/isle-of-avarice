--!strict
local Types = require("../Types")
local Combat = require("./Combat")

type Vec3 = Types.Vec3
type Fighter = Combat.Fighter

local Targeting = {}

Targeting.SHOT_RADIUS = 2.5
Targeting.DASH_WIDTH = 3

-- Normalised horizontal look, or nil for a zero-length or non-finite look.
local function horizontalLook(attacker: Fighter): (number?, number?)
	local x, z = attacker.look.x, attacker.look.z
	local length = math.sqrt(x * x + z * z)
	if not (length > 0 and length < math.huge) then
		return nil, nil
	end
	return x / length, z / length
end

function Targeting.ahead(attacker: Fighter, distance: number): Vec3
	local x, z = horizontalLook(attacker)
	if x == nil or z == nil then
		return { x = attacker.position.x, y = attacker.position.y, z = attacker.position.z }
	end
	return {
		x = attacker.position.x + x * distance,
		y = attacker.position.y,
		z = attacker.position.z + z * distance,
	}
end

-- Fighters within reach of a ray (direction dirX, dirZ) from the attacker: distance along the
-- ray in (0, length], distance from the ray at most width. Returns the nearest along the ray, or
-- the taunter when it qualifies. Comparisons are written so NaN fails closed.
local function scanRay(
	attacker: Fighter,
	others: { Fighter },
	dirX: number,
	dirZ: number,
	length: number,
	width: number,
	taunter: number?
): number?
	local bestId: number? = nil
	local bestAlong = math.huge
	for _, other in others do
		if other.id == attacker.id then
			continue
		end
		if not (math.abs(other.position.y - attacker.position.y) <= Combat.STRIKE_MAX_HEIGHT) then
			continue
		end
		local dx = other.position.x - attacker.position.x
		local dz = other.position.z - attacker.position.z
		local along = dx * dirX + dz * dirZ
		local across = math.abs(dx * dirZ - dz * dirX)
		if not (along > 0 and along <= length and across <= width) then
			continue
		end
		if taunter ~= nil and other.id == taunter then
			return other.id
		end
		if along < bestAlong then
			bestAlong = along
			bestId = other.id
		end
	end
	return bestId
end

-- Positive angleDegrees turns the look clockwise seen from above (from -z towards +x).
function Targeting.shot(
	attacker: Fighter,
	others: { Fighter },
	range: number,
	angleDegrees: number,
	taunter: number?
): number?
	local lookX, lookZ = horizontalLook(attacker)
	if lookX == nil or lookZ == nil then
		return nil
	end
	local angle = math.rad(angleDegrees)
	local sin, cos = math.sin(angle), math.cos(angle)
	local dirX = lookX * cos - lookZ * sin
	local dirZ = lookX * sin + lookZ * cos
	return scanRay(attacker, others, dirX, dirZ, range, Targeting.SHOT_RADIUS, taunter)
end

function Targeting.inRadius(
	center: Vec3,
	others: { Fighter },
	radius: number,
	excludeId: number?
): { number }
	local ids: { number } = {}
	for _, other in others do
		if excludeId ~= nil and other.id == excludeId then
			continue
		end
		if not (math.abs(other.position.y - center.y) <= Combat.STRIKE_MAX_HEIGHT) then
			continue
		end
		local dx = other.position.x - center.x
		local dz = other.position.z - center.z
		if dx * dx + dz * dz <= radius * radius then
			table.insert(ids, other.id)
		end
	end
	table.sort(ids)
	return ids
end

function Targeting.dashHit(attacker: Fighter, others: { Fighter }, distance: number): number?
	local lookX, lookZ = horizontalLook(attacker)
	if lookX == nil or lookZ == nil then
		return nil
	end
	return scanRay(attacker, others, lookX, lookZ, distance, Targeting.DASH_WIDTH, nil)
end

return Targeting
