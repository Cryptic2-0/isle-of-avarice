--!strict
local Geography = require("../Rules/Geography")
local Sites = require("./Sites")
local Thornwood = require("./SiteData/Thornwood")
local Types = require("../Types")

type Cache = Types.Cache

local islandHalfSize = 1380
local groundY = 0
local spawn: Types.Vec3 = { x = 0, y = 0.7, z = 0 }
local townRadius = Geography.TOWN_RADIUS
-- The Edict Hall clerk, between the two north buildings of Tallyport.
local clerk: Types.Vec3 = { x = 0, y = 0, z = -24 }
-- The Tally Stone, on the south side of the plaza.
local tallyStone: Types.Vec3 = { x = 0, y = 0, z = 32 }

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

-- A spot in a wild region's own frame: `along` out from the island centre down the region's
-- bearing, `across` to the right of that line.
local function spot(regionId: string, along: number, across: number, y: number): Types.Vec3
	local x, z = Geography.place(regionId, along, across)
	return { x = x, y = y, z = z }
end

-- A stack of square ledges to jump up, centred on a spot. Ledges are 8 wide, 10 apart and
-- rise 4 each; they run in rows of `perRow` that double back, so the next ledge is always
-- the only one within a jump. Ledges are square to the world's axes whatever the region.
local LEDGE_SIZE = 8
local LEDGE_STEP = 10
local LEDGE_RISE = 4
local function climb(centre: Types.Vec3, count: number, perRow: number): { Types.Ledge }
	local rows = math.ceil(count / perRow)
	local ledges: { Types.Ledge } = {}
	for i = 0, count - 1 do
		local row = math.floor(i / perRow)
		local col = i % perRow
		if row % 2 == 1 then
			col = perRow - 1 - col
		end
		table.insert(ledges, {
			x = centre.x + (col - (perRow - 1) / 2) * LEDGE_STEP,
			z = centre.z + (row - (rows - 1) / 2) * LEDGE_STEP,
			size = LEDGE_SIZE,
			top = (i + 1) * LEDGE_RISE,
		})
	end
	return ledges
end

-- Caches C019 to C021 sit on top of climbs: R017 above Thornwood's north shore, R018 on the
-- far flank of Bastion Reach, and R026 on the Lookout's crag, the island's highest point.
local climbs: { [string]: { Types.Ledge } } = {}
local function addClimbCache(
	relicId: string,
	centre: Types.Vec3,
	count: number,
	perRow: number,
	hold: number?
)
	local ledges = climb(centre, count, perRow)
	local last = ledges[#ledges]
	addCache(relicId, last.x, last.top + 1, last.z, hold)
	climbs[caches[#caches].id] = ledges
end
addClimbCache("R017", spot("Thornwood", 870, 160, 0), 5, 3)
addClimbCache("R018", spot("BastionReach", 800, 290, 0), 6, 3)
addClimbCache("R026", spot("SquallSteps", 550, 220, 0), 16, 4)
-- The Cliff Warden's course: one straight flight beside the Squall Steps gate.
climbs.gullstep_climb = climb(spot("SquallSteps", 350, 100, 0), 7, 7)

-- Caches C022 to C024: Copper, in far corners of the wilds.
for _, far in
	{
		{ relicId = "R028", at = spot("SquallSteps", 440, -110, 1) },
		{ relicId = "R029", at = spot("DrownedFen", 885, -60, 1) },
		{ relicId = "R030", at = spot("Thornwood", 860, -150, 1) },
	}
do
	addCache(far.relicId, far.at.x, far.at.y, far.at.z, nil)
end

-- Caches C025 to C031 (M7): two more far Copper caches, one at the blight's edge, one in the
-- maze's dead end, one on the Rock (held), then two climbs (the second held, for the Crown).
local mazeAlong, mazeAcross = Thornwood.cellCentre(14, 8)
local m7Caches: { { relicId: string, at: Types.Vec3, hold: number? } } = {
	{ relicId = "R032", at = spot("CinderFlats", 700, -260, 1) },
	{ relicId = "R033", at = spot("BastionReach", 650, -260, 1) },
	{ relicId = "R034", at = spot("HushGardens", 245, -115, 1) },
	{ relicId = "R038", at = spot("Thornwood", mazeAlong, mazeAcross, 1) },
	{ relicId = "R044", at = { x = 0, y = 1, z = 1290 }, hold = 3 },
}
for _, extra in m7Caches do
	addCache(extra.relicId, extra.at.x, extra.at.y, extra.at.z, extra.hold)
end
addClimbCache("R039", spot("CinderFlats", 520, -270, 0), 6, 3)
addClimbCache("R050", spot("DrownedFen", 650, 230, 0), 12, 4, 10)

-- One Warden per trial, beside the road at a region's gate. The Harbour Warden stands at the
-- head of the west Sluice, inside the ring the Hush Gardens blight does not reach.
local harbour = spot("HushGardens", 285, 80, 0)
local wardens: { [string]: Types.Vec3 } = {
	tidewalk = harbour,
	gullstep_climb = spot("SquallSteps", 300, 45, 0),
	salt_post = spot("CinderFlats", 300, 45, 0),
	cull_the_pack = spot("Thornwood", 300, 45, 0),
	shellbreaker = spot("DrownedFen", 300, 45, 0),
	tallymans_duel = spot("BastionReach", 300, 45, 0),
	reed_run = spot("DrownedFen", 300, -45, 0),
	bellows_dance = spot("CinderFlats", 380, 55, 0),
	spitter_season = spot("CinderFlats", 300, -45, 0),
	-- The Crown Warden stands in Tallyport.
	grand_tally = { x = -14, y = 0, z = 24 },
}
local duelArena = spot("BastionReach", 330, 120, 0)

-- Course markers in order, at the height of a standing character's root (surface + 3).
local MARKER_LIFT = 3
local gullstep: { Types.Vec3 } = {}
do
	local first = climbs.gullstep_climb[1]
	table.insert(gullstep, { x = first.x - LEDGE_STEP, y = MARKER_LIFT, z = first.z })
	for _, ledge in climbs.gullstep_climb do
		table.insert(gullstep, { x = ledge.x, y = ledge.top + MARKER_LIFT, z = ledge.z })
	end
end
local courses: { [string]: { Types.Vec3 } } = {
	-- Along the blight-free edge of the Hush Gardens, away from the harbour.
	tidewalk = {
		spot("HushGardens", 305, 65, MARKER_LIFT),
		spot("HushGardens", 285, 30, MARKER_LIFT),
		spot("HushGardens", 305, -10, MARKER_LIFT),
		spot("HushGardens", 285, -35, MARKER_LIFT),
		spot("HushGardens", 295, -95, MARKER_LIFT),
		spot("HushGardens", 285, -125, MARKER_LIFT),
	},
	gullstep_climb = gullstep,
	-- Along the boardwalks of the Drowned Fen, above the bog (the boardwalk top is 0.6).
	reed_run = {
		spot("DrownedFen", 420, 0, 3.6),
		spot("DrownedFen", 510, 0, 3.6),
		spot("DrownedFen", 600, 0, 3.6),
		spot("DrownedFen", 700, 0, 3.6),
		spot("DrownedFen", 780, 0, 3.6),
		spot("DrownedFen", 850, 0, 3.6),
	},
	-- Across the vent centres of the Cinder Flats.
	bellows_dance = {
		spot("CinderFlats", 440, -80, 3),
		spot("CinderFlats", 520, -40, 3),
		spot("CinderFlats", 600, 0, 3),
		spot("CinderFlats", 520, 40, 3),
		spot("CinderFlats", 440, 80, 3),
	},
	-- One marker in every wild region, then Reckoning Rock.
	grand_tally = {
		spot("HushGardens", 440, 0, 3),
		spot("BastionReach", 470, 30, 3),
		spot("Thornwood", 450, 0, 3),
		spot("SquallSteps", 450, 0, 3),
		spot("CinderFlats", 410, 0, 3),
		spot("DrownedFen", 390, -60, 3),
		{ x = 40, y = 3, z = 1220 },
	},
}

-- Creature dens, out in the wilds. Order matters: creature ids follow it.
local function den(
	kind: string,
	count: number,
	regionId: string,
	along: number,
	across: number
): Types.Den
	return { kind = kind, count = count, position = spot(regionId, along, across, 0) }
end
local dens: { Types.Den } = {
	den("brinehound", 3, "Thornwood", 380, -110),
	den("brinehound", 3, "Thornwood", 570, -260),
	den("brinehound", 3, "BastionReach", 460, 190),
	den("brinehound", 3, "BastionReach", 420, -60),
	den("shellback", 2, "DrownedFen", 320, 130),
	den("shellback", 2, "DrownedFen", 560, 270),
	den("shellback", 2, "SquallSteps", 640, 200),
	den("bogspitter", 2, "DrownedFen", 760, 300),
	den("bogspitter", 2, "Thornwood", 900, 0),
	den("bogspitter", 2, "CinderFlats", 380, -140),
	den("brine_colossus", 1, "SquallSteps", 780, 240),
	den("gilded_bailiff", 1, "CinderFlats", 820, -230),
}

-- Den creature n (den order, then member order) has id CREATURE_ID_BASE - n. A duel champion
-- has an id below CHAMPION_ID_BASE. Both are negative and clear of posts and Studio test
-- players, so no fighter id is ever mistaken for another kind.
local CREATURE_ID_BASE = -2000000
local CHAMPION_ID_BASE = -3000000
local creatureSlots: { { id: number, den: number, kind: string } } = {}
for denIndex, entry in dens do
	for _ = 1, entry.count do
		table.insert(creatureSlots, {
			id = CREATURE_ID_BASE - (#creatureSlots + 1),
			den = denIndex,
			kind = entry.kind,
		})
	end
end

local function creatureIndex(id: number): number?
	local n = CREATURE_ID_BASE - id
	if n >= 1 and n <= #creatureSlots and n == math.floor(n) then
		return n
	end
	return nil
end

-- Written so NaN and infinities are refused.
local function isChampion(id: number): boolean
	local k = CHAMPION_ID_BASE - id
	return k >= 1 and k < math.huge and k == math.floor(k)
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
	clerk = clerk,
	tallyStone = tallyStone,
	caches = caches,
	cacheById = cacheById,
	climbs = climbs,
	wardens = wardens,
	harbour = harbour,
	duelArena = duelArena,
	courses = courses,
	dens = dens,
	CREATURE_ID_BASE = CREATURE_ID_BASE,
	creatureSlots = creatureSlots,
	creatureIndex = creatureIndex,
	CHAMPION_ID_BASE = CHAMPION_ID_BASE,
	isChampion = isChampion,
}
