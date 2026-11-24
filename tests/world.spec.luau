--!strict
local T = require("./harness")
local Geography = require("../src/shared/Rules/Geography")
local Hazards = require("../src/shared/Rules/Hazards")
local Regions = require("../src/shared/Catalog/Regions")
local Relics = require("../src/shared/Catalog/Relics")
local Sites = require("../src/shared/Catalog/Sites")
local World = require("../src/shared/Catalog/World")

T.test("eighteen caches on land, outside Tallyport", function()
	T.eq(#World.caches, 18)
	for i, cache in World.caches do
		T.eq(cache.id, string.format("C%03d", i))
		T.eq(World.cacheById[cache.id], cache)
		T.eq(cache.relicId, string.format("R%03d", if i <= 12 then i else i - 12))
		T.truthy(Geography.isLand(cache.position.x, cache.position.z), cache.id .. " on land")
		T.truthy(Geography.regionAt(cache.position.x, cache.position.z) ~= "Tallyport", cache.id)
	end
end)

T.test("Copper caches stay in the Fields; prizes sit in their regions", function()
	T.eq(World.cacheById.C001.position, { x = 60, y = 1, z = 40 })
	T.eq(World.cacheById.C006.position, { x = -130, y = 1, z = -10 })
	for i = 1, 6 do
		local cache = World.caches[i]
		T.eq(Geography.regionAt(cache.position.x, cache.position.z), "CountingFields")
		T.eq(cache.hold, nil)
	end
	local expected: { [string]: string } = {
		C007 = "SquallSteps",
		C008 = "HushGardens",
		C009 = "Thornwood",
		C010 = "ReckoningRock",
		C011 = "CinderFlats",
		C012 = "BastionReach",
	}
	for id, region in expected do
		local cache = World.cacheById[id]
		T.eq(Geography.regionAt(cache.position.x, cache.position.z), region, id)
		T.eq(cache.hold, if id == "C012" then 4 else 3, id)
	end
	T.eq(World.cacheById.C007.position.y, 58)
	T.eq(World.cacheById.C011.position.y, 1.6)
	local x, z = Geography.place("BastionReach", 820, 0)
	T.eq(World.cacheById.C012.position, { x = x, y = 1, z = z })
	for k, region in Regions.wild do
		local cache = World.caches[12 + k]
		local ex, ez = Geography.place(region, 310, -60)
		T.eq(cache.position, { x = ex, y = 1, z = ez })
		T.eq(cache.hold, nil)
	end
end)

T.test("every Relic in the catalog has at least one cache", function()
	local covered: { [string]: boolean } = {}
	for _, cache in World.caches do
		covered[cache.relicId] = true
		T.truthy(Relics.byId[cache.relicId] ~= nil, cache.id .. " holds a known relic")
	end
	for _, relic in Relics.list do
		T.truthy(covered[relic.id], relic.id .. " has a cache")
	end
end)

T.test("constants", function()
	T.eq(World.islandHalfSize, 1380)
	T.eq(World.groundY, 0)
	T.eq(World.townRadius, 40)
	T.eq(World.spawn, { x = 0, y = 0.7, z = 0 })
end)

T.test("six training posts outside Tallyport, inside the island, with stable ids", function()
	T.eq(#World.trainingPosts, 6)
	for i, post in World.trainingPosts do
		local d = math.sqrt(post.x ^ 2 + post.z ^ 2)
		T.truthy(d > World.townRadius and d <= 380, "post " .. i .. " placement")
		T.eq(post.y, 0)
	end
	T.eq(World.POST_ID_BASE, -1000000)
	T.eq(World.postIndex(World.POST_ID_BASE - 4), 4)
	T.eq(World.postIndex(World.POST_ID_BASE - 1), 1)
	T.eq(World.postIndex(World.POST_ID_BASE - 7), nil)
	T.eq(World.postIndex(-3), nil)
end)

T.test("the Fields are safe: no hazard within 270 of the centre at any time", function()
	local empty = { dps = 0, heal = 0, slow = 1, pushX = 0, pushZ = 0, bursts = {}, names = {} }
	for now = 0, 120, 7.5 do
		for x = -270, 270, 15 do
			for z = -270, 270, 15 do
				if x * x + z * z <= 270 * 270 then
					T.eq(
						Hazards.sample(Sites.hazards, x, z, now),
						empty,
						x .. "," .. z .. " at " .. now
					)
				end
			end
		end
	end
end)

T.test("no solid feature stands in the Fields", function()
	for _, f in Sites.features do
		if f.solid then
			T.truthy(math.sqrt(f.x * f.x + f.z * f.z) >= 280)
		end
	end
end)
