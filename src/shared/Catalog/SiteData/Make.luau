--!strict
local Geography = require("../../Rules/Geography")
local Types = require("../../Types")

local Make = {}

-- A feature covering the region-frame rectangle a1..a2 along, c1..c2 across, from height y1
-- to y2. Its yaw is the region's bearing.
function Make.block(
	regionId: string,
	a1: number,
	a2: number,
	c1: number,
	c2: number,
	y1: number,
	y2: number,
	look: string,
	solid: boolean
): Types.Feature
	local footprint = Geography.rect(regionId, a1, a2, c1, c2)
	return {
		look = look,
		shape = "block",
		x = footprint.x,
		y = (y1 + y2) / 2,
		z = footprint.z,
		sx = 2 * footprint.halfAcross,
		sy = y2 - y1,
		sz = 2 * footprint.halfAlong,
		yaw = footprint.bearing,
		solid = solid,
	}
end

-- An upright cylinder from height y1 to y2.
function Make.disc(
	regionId: string,
	along: number,
	across: number,
	radius: number,
	y1: number,
	y2: number,
	look: string,
	solid: boolean
): Types.Feature
	local footprint = Geography.rect(regionId, along, along, across, across)
	return {
		look = look,
		shape = "cylinder",
		x = footprint.x,
		y = (y1 + y2) / 2,
		z = footprint.z,
		sx = 2 * radius,
		sy = y2 - y1,
		sz = 2 * radius,
		yaw = footprint.bearing,
		solid = solid,
	}
end

return Make
