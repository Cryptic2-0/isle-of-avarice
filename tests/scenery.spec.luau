--!strict
local T = require("./harness")
local Geography = require("../src/shared/Rules/Geography")
local Hazards = require("../src/shared/Rules/Hazards")
local Looks = require("../src/shared/Catalog/Looks")
local Regions = require("../src/shared/Catalog/Regions")
local Scenery = require("../src/shared/Catalog/SiteData/Scenery")
local Sites = require("../src/shared/Catalog/Sites")
local Types = require("../src/shared/Types")

local function siteOf(region: string): Types.Site
	for _, site in Sites.list do
		if site.region == region then
			return site
		end
	end
	error(`no site for {region}`)
end

T.test("scatter is deterministic and respects the site", function()
	for index, region in Regions.wild do
		local site = siteOf(region)
		local a = Scenery.scatter(site, index)
		T.eq(Scenery.scatter(site, index), a)
		T.truthy(#a >= 24, region .. " has scenery")
		local ex, ez = Geography.place(region, 310, -60)
		for _, f in a do
			T.truthy(Geography.isLand(f.x, f.z) and Geography.regionAt(f.x, f.z) == region)
			T.truthy(Looks.byName[f.look] ~= nil)
			for _, shape in site.keepOut do
				T.falsy(Hazards.contains(shape, f.x, f.z))
			end
			T.truthy(math.sqrt((f.x - ex) ^ 2 + (f.z - ez) ^ 2) >= 30)
			local along, across =
				Geography.toFrame(Regions.byId[region].bearing :: number, f.x, f.z)
			T.falsy(math.abs(across) < 16 and along < 480)
		end
	end
end)
