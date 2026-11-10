--!strict
local T = require("./harness")
local Relics = require("../src/shared/Catalog/Relics")
local World = require("../src/shared/Catalog/World")

T.test("twelve caches with matching ids, inside the island, outside Tallyport", function()
	T.eq(#World.caches, 12)
	for i, cache in World.caches do
		T.eq(cache.id, string.format("C%03d", i))
		T.eq(cache.relicId, string.format("R%03d", i))
		T.eq(World.cacheById[cache.id], cache)
		T.truthy(
			math.abs(cache.position.x) <= 380 and math.abs(cache.position.z) <= 380,
			cache.id .. " on island"
		)
		local d = math.sqrt(cache.position.x ^ 2 + cache.position.z ^ 2)
		T.truthy(d > World.townRadius, cache.id .. " outside Tallyport")
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

T.test("constants and spot checks", function()
	T.eq(World.islandHalfSize, 400)
	T.eq(World.groundY, 0)
	T.eq(World.townRadius, 40)
	T.eq(World.spawn, { x = 0, y = 3, z = 0 })
	T.eq(World.cacheById.C012.position, { x = -40, y = 1.5, z = 370 })
	T.eq(World.cacheById.C001.position, { x = 60, y = 1.5, z = 40 })
end)
