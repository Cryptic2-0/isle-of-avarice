--!strict
local Geography = require("../Rules/Geography")
local Sites = require("./Sites")
local Types = require("../Types")

type Cache = Types.Cache

local islandHalfSize = 1380
local groundY = 0
local spawn: Types.Vec3 = { x = 0, y = 0.7, z = 0 }
local townRadius = Geography.TOWN_RADIUS

-- Caches C001 to C006 hold Relics R001 to R006 in the Counting Fields.
local fieldLayout: { { number } } = {
	{ 60, 40 },
	{ -70, 55 },
	{ 90, -60 },
	{ -50, -95 },
	{ 120, 20 },
	{ -130, -10 },
}

local caches: { Cache } = {}
local cacheById: { [string]: Cache } = {}
local function addCache(relicId: string, x: number, y: number, z: number, hold: number?)
	local cache: Cache = {
		id = string.format("C%03d", #caches + 1),
		relicId = relicId,
		position = { x = x, y = y, z = z },
		hold = hold,
	}
	table.insert(caches, cache)
	cacheById[cache.id] = cache
end

for i, xz in fieldLayout do
	addCache(string.format("R%03d", i), xz[1], 1, xz[2], nil)
end

-- Caches C007 to C012 hold Relics R007 to R012, each at the prize of the site that holds it.
local prizes: { [string]: Types.SiteCache } = {}
for _, site in Sites.list do
	if site.prize ~= nil then
		prizes[site.prize.relicId] = site.prize
	end
end
for n = 7, 12 do
	local relicId = string.format("R%03d", n)
	local prize = prizes[relicId]
	if prize == nil then
		error(`World: no site holds {relicId}`)
	end
	addCache(relicId, prize.x, prize.y, prize.z, prize.hold)
end

-- Caches C013 to C018 are the Copper caches out in the wild regions.
for _, extra in Sites.extras do
	addCache(extra.relicId, extra.x, extra.y, extra.z, extra.hold)
end

local trainingPosts: { Types.Vec3 } = {
	{ x = 55, y = 0, z = 0 },
	{ x = 28, y = 0, z = 48 },
	{ x = -28, y = 0, z = 48 },
	{ x = -55, y = 0, z = 0 },
	{ x = -28, y = 0, z = -48 },
	{ x = 28, y = 0, z = -48 },
}
-- Post i has id POST_ID_BASE - i; negative, so it never collides with a player UserId.
local POST_ID_BASE = -1000000

local function postIndex(id: number): number?
	local i = POST_ID_BASE - id
	if i >= 1 and i <= #trainingPosts and i == math.floor(i) then
		return i
	end
	return nil
end

return {
	trainingPosts = trainingPosts,
	POST_ID_BASE = POST_ID_BASE,
	postIndex = postIndex,
	islandHalfSize = islandHalfSize,
	groundY = groundY,
	spawn = spawn,
	townRadius = townRadius,
	caches = caches,
	cacheById = cacheById,
}
