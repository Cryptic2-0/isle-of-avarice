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

-- The bursts that land now: those whose hazard has not hit in this cycle index. Returns them in
-- order and the new record; `seen` is not changed.
function Hazards.landing(
	seen: { [string]: number }?,
	bursts: { Burst }
): ({ Burst }, { [string]: number })
	local record: { [string]: number } = if seen then table.clone(seen) else {}
	local landing: { Burst } = {}
	for _, burst in bursts do
		if record[burst.id] ~= burst.cycle then
			table.insert(landing, burst)
			record[burst.id] = burst.cycle
		end
	end
	return landing, record
end

-- For a region-wide hazard: the parts of its region's ground strips at or beyond its radius,
-- judged on each strip's centre line. Any other shape has none.
function Hazards.overlay(hazard: Types.Hazard, strips: { Geography.Strip }): { Geography.Strip }
	local pieces: { Geography.Strip } = {}
	local shape = hazard.shape
	if shape.kind ~= "region" then
		return pieces
	end
	local radius = shape.radius
	for _, strip in strips do
		if strip.region == shape.region then
			if math.abs(strip.z) >= radius then
				table.insert(pieces, table.clone(strip))
			else
				local c = math.sqrt(radius * radius - strip.z * strip.z)
				if strip.x1 < -c then
					table.insert(pieces, {
						z = strip.z,
						x1 = strip.x1,
						x2 = math.min(strip.x2, -c),
						region = strip.region,
					})
				end
				if strip.x2 > c then
					table.insert(pieces, {
						z = strip.z,
						x1 = math.max(strip.x1, c),
						x2 = strip.x2,
						region = strip.region,
					})
				end
			end
		end
	end
	return pieces
end

return Hazards
