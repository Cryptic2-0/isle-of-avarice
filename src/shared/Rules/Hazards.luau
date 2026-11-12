--!strict
local Geography = require("./Geography")
local Types = require("../Types")

export type Phase = "idle" | "warn" | "active"
export type Burst = { id: string, damage: number, cycle: number }
export type Sample = {
	dps: number,
	heal: number,
	slow: number, -- smallest speed multiplier in effect; 1 when none
	pushX: number,
	pushZ: number,
	bursts: { Burst },
	names: { string },
}

local Hazards = {}

Hazards.TICK_SECONDS = 0.25
Hazards.SLOW_SECONDS = 1

local function isFinite(n: number): boolean
	return n > -math.huge and n < math.huge
end

-- A point that is not a finite number is inside nothing.
function Hazards.contains(shape: Types.Shape, x: number, z: number): boolean
	if not (isFinite(x) and isFinite(z)) then
		return false
	end
	if shape.kind == "circle" then
		local dx, dz = x - shape.x, z - shape.z
		return dx * dx + dz * dz <= shape.radius * shape.radius
	elseif shape.kind == "rect" then
		local along, across = Geography.toFrame(shape.bearing, x - shape.x, z - shape.z)
		return math.abs(along) <= shape.halfAlong and math.abs(across) <= shape.halfAcross
	elseif shape.kind == "region" then
		return Geography.regionAt(x, z) == shape.region and math.sqrt(x * x + z * z) >= shape.radius
	end
	return false
end

-- Inside the shape and inside none of its holes.
function Hazards.affects(hazard: Types.Hazard, x: number, z: number): boolean
	if not Hazards.contains(hazard.shape, x, z) then
		return false
	end
	if hazard.holes then
		for _, hole in hazard.holes do
			if Hazards.contains(hole, x, z) then
				return false
			end
		end
	end
	return true
end

-- The phase, the cycle index, and the fraction of the current phase already elapsed (0..1).
function Hazards.phase(hazard: Types.Hazard, now: number): (Phase, number, number)
	local cycle = hazard.cycle
	if cycle == nil then
		return "active", 0, 0
	end
	if not isFinite(now) then
		return "idle", 0, 0
	end
	local shifted = now + cycle.offset
	local t = shifted % cycle.period
	local index = math.floor(shifted / cycle.period)
	local idle = cycle.period - cycle.warn - cycle.active
	if t < idle then
		return "idle", index, t / idle
	elseif t < idle + cycle.warn then
		return "warn", index, (t - idle) / cycle.warn
	end
	return "active", index, math.min((t - idle - cycle.warn) / cycle.active, 1)
end

-- The combined effect on a point at time now. Only active hazards that affect the point count.
function Hazards.sample(list: { Types.Hazard }, x: number, z: number, now: number): Sample
	local sample: Sample = {
		dps = 0,
		heal = 0,
		slow = 1,
		pushX = 0,
		pushZ = 0,
		bursts = {},
		names = {},
	}
	for _, hazard in list do
		if Hazards.affects(hazard, x, z) then
			local phase, index = Hazards.phase(hazard, now)
			if phase == "active" then
				sample.dps += hazard.dps or 0
				sample.heal += hazard.heal or 0
				if hazard.slow ~= nil then
					sample.slow = math.min(sample.slow, hazard.slow)
				end
				if hazard.push ~= nil then
					sample.pushX += hazard.push.x
					sample.pushZ += hazard.push.z
				end
				if hazard.damage ~= nil then
					table.insert(
						sample.bursts,
						{ id = hazard.id, damage = hazard.damage, cycle = index }
					)
				end
				if not table.find(sample.names, hazard.name) then
					table.insert(sample.names, hazard.name)
				end
			end
		end
	end
	return sample
end

return Hazards
