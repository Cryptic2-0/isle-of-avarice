--!strict
local T = require("./harness")
local Geography = require("../src/shared/Rules/Geography")
local PlaceView = require("../src/shared/Rules/PlaceView")

T.test("names the region and the hazards in effect", function()
	T.eq(PlaceView.at(0, 0, 0), {
		regionId = "Tallyport",
		name = "Tallyport",
		hint = "Safe ground. No fighting here.",
		hazards = {},
	})
	local x, z = Geography.place("HushGardens", 470, 0)
	local place = PlaceView.at(x, z, 0)
	T.eq(place.regionId, "HushGardens")
	T.eq(place.name, "Hush Gardens")
	T.eq(place.hazards, { "Blight", "Spring" })
	T.eq(PlaceView.at(0, 1050, 90).hazards, { "High tide" })
	T.eq(PlaceView.at(0, 1050, 10).hazards, {})
	T.eq(PlaceView.at(0 / 0, 0, 0).regionId, "CountingFields")
end)
