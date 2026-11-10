--!strict
local Types = require("../Types")

type Cache = Types.Cache

local islandHalfSize = 400
local groundY = 0
local spawn: Types.Vec3 = { x = 0, y = 0.7, z = 0 }
local townRadius = 40

-- Cache C0NN holds Relic R0NN.
local layout: { { number } } = {
	{ 60, 40 },
	{ -70, 55 },
	{ 90, -60 },
	{ -50, -95 },
	{ 120, 20 },
	{ -130, -10 },
	{ 200, 140 },
	{ -220, 110 },
	{ 30, -250 },
	{ -290, -170 },
	{ 300, -120 },
	{ -40, 370 },
}

local caches: { Cache } = {}
local cacheById: { [string]: Cache } = {}
for i, xz in layout do
	local cache: Cache = {
		id = string.format("C%03d", i),
		relicId = string.format("R%03d", i),
		position = { x = xz[1], y = 1, z = xz[2] },
	}
	table.insert(caches, cache)
	cacheById[cache.id] = cache
end

return {
	islandHalfSize = islandHalfSize,
	groundY = groundY,
	spawn = spawn,
	townRadius = townRadius,
	caches = caches,
	cacheById = cacheById,
}
