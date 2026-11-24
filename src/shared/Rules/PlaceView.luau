--!strict
-- Where a point is and which hazards are in effect there. Pure: the client shows this.
local Geography = require("./Geography")
local Hazards = require("./Hazards")
local Regions = require("../Catalog/Regions")
local Sites = require("../Catalog/Sites")

export type Place = { regionId: string, name: string, hint: string, hazards: { string } }

local PlaceView = {}

-- The region at (x, z) and the names of the hazards active there at server time `now`.
-- A position that is not a finite number reads as Counting Fields with no hazards.
function PlaceView.at(x: number, z: number, now: number): Place
	local regionId = Geography.regionAt(x, z)
	local region = Regions.byId[regionId]
	local sample = Hazards.sample(Sites.hazards, x, z, now)
	return {
		regionId = regionId,
		name = region.name,
		hint = region.hint,
		hazards = sample.names,
	}
end

return PlaceView
