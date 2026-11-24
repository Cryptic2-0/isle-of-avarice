--!strict
local Types = require("../Types")
local Regions = require("../Catalog/Regions")

export type Strip = { z: number, x1: number, x2: number, region: Types.RegionId }
export type Bridge = { x: number, z: number, yaw: number, length: number, width: number }

local Geography = {}

Geography.CELL = 40
Geography.GRID = 34
Geography.TOWN_RADIUS = 40
Geography.FIELDS_RADIUS = 260
Geography.DROWN_Y = -6
Geography.ROCK = { x = 0, z = 1240, radius = 80 }

local CELL = Geography.CELL
local GRID = Geography.GRID
local ROCK = Geography.ROCK
local CAUSEWAY_MIN_Z = 940
local CAUSEWAY_MAX_Z = 1160
local RIVER_BEARINGS = { 30, 150, 270 }
local RIVER_START = 300
local RIVER_HALF_WIDTH = 50
local BRIDGE_ALONG = { 420, 760 }
local BRIDGE_LENGTH = 180
local BRIDGE_WIDTH = 16

local function isFinite(n: number): boolean
	return n > -math.huge and n < math.huge
end

-- Degrees clockwise from north (-Z), in [0, 360). The centre has no direction and reads as 0.
function Geography.bearingOf(x: number, z: number): number
	if x == 0 and z == 0 then
		return 0
	end
	local b = math.deg(math.atan2(x, -z))
	if b < 0 then
		b += 360
		-- A tiny negative angle rounds up to exactly 360.
		if b >= 360 then
			b = 0
		end
	end
	return b
end

function Geography.coastRadius(bearing: number): number
	local t = math.rad(bearing)
	return 960 + 60 * math.sin(3 * t) + 40 * math.sin(5 * t + 1)
end

-- World x, z to a region frame: distance down the bearing, distance to the right of it.
function Geography.toFrame(bearing: number, x: number, z: number): (number, number)
	local t = math.rad(bearing)
	local s, c = math.sin(t), math.cos(t)
	return x * s - z * c, x * c + z * s
end

function Geography.fromFrame(bearing: number, along: number, across: number): (number, number)
	local t = math.rad(bearing)
	local s, c = math.sin(t), math.cos(t)
	return along * s + across * c, -along * c + across * s
end

local function bearingOfRegion(regionId: string): number
	local region = Regions.byId[regionId]
	local bearing = if region then region.bearing else nil
	if bearing == nil then
		error(`Geography: region {regionId} has no bearing`)
	end
	return bearing
end

function Geography.place(regionId: string, along: number, across: number): (number, number)
	return Geography.fromFrame(bearingOfRegion(regionId), along, across)
end

function Geography.cellOf(x: number, z: number): (number, number)
	return math.floor(x / CELL + 0.5), math.floor(z / CELL + 0.5)
end

-- The region owning cell (i, j), judged at the cell centre. Tallyport is not a cell region:
-- its circle is smaller than a cell and regionAt answers for it.
function Geography.cellRegion(i: number, j: number): Types.RegionId
	local x, z = CELL * i, CELL * j
	local rx, rz = x - ROCK.x, z - ROCK.z
	if rx * rx + rz * rz <= ROCK.radius * ROCK.radius then
		return "ReckoningRock"
	end
	if i == 0 and CAUSEWAY_MIN_Z <= z and z <= CAUSEWAY_MAX_Z then
		return "ReckoningRock"
	end
	if math.sqrt(x * x + z * z) <= Geography.FIELDS_RADIUS then
		return "CountingFields"
	end
	return Regions.wild[math.floor((Geography.bearingOf(x, z) + 30) / 60) % 6 + 1]
end

function Geography.cellIsLand(i: number, j: number): boolean
	if math.abs(i) > GRID or math.abs(j) > GRID then
		return false
	end
	if Geography.cellRegion(i, j) == "ReckoningRock" then
		return true
	end
	local x, z = CELL * i, CELL * j
	if math.sqrt(x * x + z * z) > Geography.coastRadius(Geography.bearingOf(x, z)) then
		return false
	end
	for _, bearing in RIVER_BEARINGS do
		local along, across = Geography.toFrame(bearing, x, z)
		if along >= RIVER_START and math.abs(across) < RIVER_HALF_WIDTH then
			return false
		end
	end
	return true
end

-- A position that is not a finite number reads as Counting Fields.
function Geography.regionAt(x: number, z: number): Types.RegionId
	if not (isFinite(x) and isFinite(z)) then
		return "CountingFields"
	end
	if x * x + z * z <= Geography.TOWN_RADIUS * Geography.TOWN_RADIUS then
		return "Tallyport"
	end
	return Geography.cellRegion(Geography.cellOf(x, z))
end

function Geography.isLand(x: number, z: number): boolean
	if not (isFinite(x) and isFinite(z)) then
		return false
	end
	return Geography.cellIsLand(Geography.cellOf(x, z))
end

-- Every land cell exactly once, as horizontal runs of one region: row z = 40j, from x1 to x2.
function Geography.strips(): { Strip }
	local strips: { Strip } = {}
	for j = -GRID, GRID do
		local runStart: number? = nil
		local runRegion: Types.RegionId = "CountingFields"
		-- One cell past the grid is never land, so it closes a run that reaches the edge.
		for i = -GRID, GRID + 1 do
			local region = if Geography.cellIsLand(i, j) then Geography.cellRegion(i, j) else nil
			if runStart ~= nil and region ~= runRegion then
				table.insert(strips, {
					z = CELL * j,
					x1 = CELL * runStart - CELL / 2,
					x2 = CELL * (i - 1) + CELL / 2,
					region = runRegion,
				})
				runStart = nil
			end
			if region ~= nil and runStart == nil then
				runStart = i
				runRegion = region
			end
		end
	end
	return strips
end

-- One bridge over each river at 420 and 760 out, lying across the river.
function Geography.bridges(): { Bridge }
	local bridges: { Bridge } = {}
	for _, bearing in RIVER_BEARINGS do
		for _, along in BRIDGE_ALONG do
			local x, z = Geography.fromFrame(bearing, along, 0)
			table.insert(bridges, {
				x = x,
				z = z,
				yaw = (bearing + 90) % 360,
				length = BRIDGE_LENGTH,
				width = BRIDGE_WIDTH,
			})
		end
	end
	return bridges
end

function Geography.circle(
	regionId: string,
	along: number,
	across: number,
	radius: number
): Types.Shape
	local x, z = Geography.place(regionId, along, across)
	return {
		kind = "circle",
		x = x,
		z = z,
		radius = radius,
		bearing = 0,
		halfAlong = 0,
		halfAcross = 0,
		region = "",
	}
end

function Geography.rect(
	regionId: string,
	a1: number,
	a2: number,
	c1: number,
	c2: number
): Types.Shape
	local x, z = Geography.place(regionId, (a1 + a2) / 2, (c1 + c2) / 2)
	return {
		kind = "rect",
		x = x,
		z = z,
		radius = 0,
		bearing = bearingOfRegion(regionId),
		halfAlong = (a2 - a1) / 2,
		halfAcross = (c2 - c1) / 2,
		region = "",
	}
end

-- Everything of the region at least minRadius from the island centre.
function Geography.regionShape(regionId: string, minRadius: number): Types.Shape
	return {
		kind = "region",
		x = 0,
		z = 0,
		radius = minRadius,
		bearing = 0,
		halfAlong = 0,
		halfAcross = 0,
		region = regionId,
	}
end

return Geography
