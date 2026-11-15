--!strict
local T = require("./harness")
local Geography = require("../src/shared/Rules/Geography")
local Hazards = require("../src/shared/Rules/Hazards")
local Regions = require("../src/shared/Catalog/Regions")
local Relics = require("../src/shared/Catalog/Relics")
local Sites = require("../src/shared/Catalog/Sites")
local Creatures = require("../src/shared/Catalog/Creatures")
local Trials = require("../src/shared/Catalog/Trials")
local Types = require("../src/shared/Types")
local World = require("../src/shared/Catalog/World")

local NEW_RELICS = { "R017", "R018", "R026", "R028", "R029", "R030" }

local function flat(a: Types.Vec3, b: Types.Vec3): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- Distance from a point to a feature's footprint edge; negative inside it.
local function featureGap(f: Types.Feature, x: number, z: number): number
	if f.shape == "cylinder" then
		return math.sqrt((x - f.x) ^ 2 + (z - f.z) ^ 2) - f.sx / 2
	end
	local along, across = Geography.toFrame(f.yaw, x - f.x, z - f.z)
	return math.max(math.abs(along) - f.sz / 2, math.abs(across) - f.sx / 2)
end

-- The least gap from the point to any solid feature of the island.
local function solidGap(x: number, z: number): number
	local best = math.huge
	for _, f in Sites.features do
		if f.solid then
			best = math.min(best, featureGap(f, x, z))
		end
	end
	return best
end

-- True when the point and a ring of points `radius` around it are land that no hazard ever
-- touches and no site keeps clear.
local function quiet(x: number, z: number, radius: number): boolean
	for i = 0, 8 do
		local px, pz = x, z
		if i > 0 then
			px = x + radius * math.cos(i * math.pi / 4)
			pz = z + radius * math.sin(i * math.pi / 4)
		end
		if not Geography.isLand(px, pz) then
			return false
		end
		for _, hazard in Sites.hazards do
			if Hazards.affects(hazard, px, pz) then
				return false
			end
		end
		for _, site in Sites.list do
			for _, shape in site.keepOut do
				if Hazards.contains(shape, px, pz) then
					return false
				end
			end
		end
	end
	return true
end

T.test("twenty-four caches on land, outside Tallyport", function()
	T.eq(#World.caches, 24)
	for i, cache in World.caches do
		T.eq(cache.id, string.format("C%03d", i))
		T.eq(World.cacheById[cache.id], cache)
		local relicId = if i <= 12
			then string.format("R%03d", i)
			elseif i <= 18 then string.format("R%03d", i - 12)
			else NEW_RELICS[i - 18]
		T.eq(cache.relicId, relicId)
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

T.test("every Relic has a source, as spec 3.11 lists them", function()
	local source: { [string]: string } = {}
	for _, cache in World.caches do
		T.truthy(Relics.byId[cache.relicId] ~= nil, cache.id .. " holds a known relic")
		source[cache.relicId] = "cache"
	end
	local function add(relicId: string, kind: string)
		T.eq(source[relicId], nil, relicId .. " has one kind of source")
		source[relicId] = kind
	end
	for _, trial in Trials.list do
		add(trial.relicId, "trial")
	end
	for _, kind in Creatures.list do
		for _, drop in kind.drops do
			add(drop.relicId, "creature")
		end
	end
	add(Trials.quest.relicId, "quest")
	for _, relic in Relics.list do
		T.truthy(source[relic.id], relic.id)
	end
	T.eq({
		source.R017,
		source.R026,
		source.R019,
		source.R023,
		source.R024,
		source.R027,
		source.R030,
	}, { "cache", "cache", "creature", "creature", "trial", "quest", "cache" })
end)

T.test("climbs can be jumped: low first ledge, small rises and gaps, clear ground", function()
	local names = {}
	for name, ledges in World.climbs do
		table.insert(names, name)
		T.truthy(#ledges >= 2, name)
		T.truthy(ledges[1].top <= 4, name)
		for i, ledge in ledges do
			T.truthy(quiet(ledge.x, ledge.z, ledge.size / 2 + 2), `{name} {i} ground`)
			T.truthy(solidGap(ledge.x, ledge.z) >= ledge.size / 2 + 2, `{name} {i} clear`)
			T.truthy(
				Geography.regionAt(ledge.x, ledge.z) == Geography.regionAt(ledges[1].x, ledges[1].z),
				`{name} {i} region`
			)
		end
		for i = 2, #ledges do
			local a, b = ledges[i - 1], ledges[i]
			T.truthy(b.top - a.top <= 4, `{name} {i} rise`)
			T.truthy(b.top > a.top, `{name} {i} goes up`)
			local gap = math.max(math.abs(b.x - a.x), math.abs(b.z - a.z)) - (a.size + b.size) / 2
			T.truthy(gap <= 4 and gap >= 0, `{name} {i} gap`)
		end
		-- No shortcut: a ledge two or more steps ahead is too high or too far to jump to.
		for i = 1, #ledges do
			for j = i + 2, #ledges do
				local a, b = ledges[i], ledges[j]
				local gap = math.max(math.abs(b.x - a.x), math.abs(b.z - a.z))
					- (a.size + b.size) / 2
				T.truthy(b.top - a.top > 7.5 or gap > 12, `{name} {i} to {j} shortcut`)
			end
		end
	end
	table.sort(names)
	T.eq(names, { "C019", "C020", "C021", "gullstep_climb" })
end)

T.test("climb caches sit on their top ledge, out of reach from the ground", function()
	local tops: { [string]: number } = { C019 = 20, C020 = 24, C021 = 64 }
	for id, top in tops do
		local cache = World.cacheById[id]
		local ledges = World.climbs[id]
		local last = ledges[#ledges]
		T.eq(last.top, top, id)
		T.eq(cache.position.y, top + 1, id)
		T.truthy(math.abs(cache.position.x - last.x) <= last.size / 2 - 1, id .. " x")
		T.truthy(math.abs(cache.position.z - last.z) <= last.size / 2 - 1, id .. " z")
		-- The collect distance is 15 studs, measured from the standing root (3 up).
		T.truthy(cache.position.y - 3 > 15, id .. " not from the ground")
		T.eq(cache.hold, nil)
	end
	T.eq({ World.cacheById.C019.relicId, World.cacheById.C020.relicId }, { "R017", "R018" })
	T.eq(World.cacheById.C021.relicId, "R026")
	-- The Lookout's crag is the highest point of the island.
	local crag = World.climbs.C021
	local peak = crag[#crag].top
	for name, ledges in World.climbs do
		if name ~= "C021" then
			T.truthy(ledges[#ledges].top < peak, name)
		end
	end
	for _, f in Sites.features do
		T.truthy(f.y + f.sy / 2 < peak, f.look)
	end
	for _, cache in World.caches do
		T.truthy(cache.id == "C021" or cache.position.y < peak, cache.id)
	end
end)

T.test("the three far Copper caches lie on quiet ground in the wilds", function()
	local expected: { [string]: { string } } = {
		C022 = { "R028", "SquallSteps" },
		C023 = { "R029", "DrownedFen" },
		C024 = { "R030", "Thornwood" },
	}
	for id, want in expected do
		local cache = World.cacheById[id]
		T.eq(cache.relicId, want[1])
		T.eq(Geography.regionAt(cache.position.x, cache.position.z), want[2], id)
		T.eq(cache.position.y, 1)
		T.truthy(quiet(cache.position.x, cache.position.z, 10), id)
		T.truthy(solidGap(cache.position.x, cache.position.z) >= 6, id)
		T.truthy(math.sqrt(cache.position.x ^ 2 + cache.position.z ^ 2) >= 400, id)
	end
end)

T.test("one Warden per trial, each at a region gate on quiet ground", function()
	local regions: { [string]: string } = {
		tidewalk = "HushGardens",
		gullstep_climb = "SquallSteps",
		salt_post = "CinderFlats",
		cull_the_pack = "Thornwood",
		shellbreaker = "DrownedFen",
		tallymans_duel = "BastionReach",
	}
	local count = 0
	for trialId, position in World.wardens do
		count += 1
		T.truthy(Trials.byId[trialId] ~= nil, trialId)
		T.eq(position.y, 0, trialId)
		T.eq(Geography.regionAt(position.x, position.z), regions[trialId], trialId)
		T.truthy(quiet(position.x, position.z, 12), trialId)
		T.truthy(solidGap(position.x, position.z) >= 8, trialId)
		local d = math.sqrt(position.x ^ 2 + position.z ^ 2)
		T.truthy(d >= 280 and d <= 330, trialId .. " at the gate")
	end
	T.eq(count, #Trials.list)
	for _, trial in Trials.list do
		T.truthy(World.wardens[trial.id] ~= nil, trial.id)
	end
	local hx, hz = Geography.place("HushGardens", 285, 80)
	T.eq(World.harbour, { x = hx, y = 0, z = hz })
	T.eq(World.wardens.tidewalk, World.harbour)
	local ax, az = Geography.place("BastionReach", 330, 120)
	T.eq(World.duelArena, { x = ax, y = 0, z = az })
	T.truthy(quiet(ax, az, 28))
	T.truthy(solidGap(ax, az) >= 28)
	-- The Salt Post run is long enough to matter and short enough for its 70 seconds.
	local run = flat(World.wardens.salt_post, World.harbour)
	T.truthy(run >= 450 and run <= 700, "salt post run " .. run)
end)

T.test("courses: Tidewalk on the ground, Gullstep up its ledges", function()
	local tide = World.courses.tidewalk
	T.eq(#tide, 6)
	local length = flat(World.harbour, tide[1])
	for i, marker in tide do
		T.eq(marker.y, 3)
		T.truthy(quiet(marker.x, marker.z, 7), "tidewalk " .. i)
		T.truthy(solidGap(marker.x, marker.z) >= 6, "tidewalk " .. i)
		if i > 1 then
			local step = flat(tide[i - 1], marker)
			T.truthy(step >= 20, "tidewalk step " .. i)
			length += step
		end
	end
	T.truthy(length >= 180 and length <= 400, "tidewalk length " .. length)

	local gull = World.courses.gullstep_climb
	local ledges = World.climbs.gullstep_climb
	T.eq(#gull, 8)
	T.eq(#ledges, 7)
	T.eq(gull[1].y, 3)
	T.truthy(quiet(gull[1].x, gull[1].z, 7))
	T.truthy(flat(gull[1], World.wardens.gullstep_climb) <= 120)
	for i = 2, 8 do
		local marker, ledge = gull[i], ledges[i - 1]
		T.eq(marker.y, ledge.top + 3, "gullstep " .. i)
		T.truthy(math.abs(marker.x - ledge.x) <= ledge.size / 2 - 1, "gullstep x " .. i)
		T.truthy(math.abs(marker.z - ledge.z) <= ledge.size / 2 - 1, "gullstep z " .. i)
		T.truthy(marker.y >= gull[i - 1].y, "gullstep rises " .. i)
	end
	T.truthy(gull[8].y >= 27)
	local count = 0
	for trialId in World.courses do
		count += 1
		T.eq(Trials.byId[trialId].kind, "course")
	end
	T.eq(count, 2)
end)

T.test("dens: the spec's packs, in the wilds, apart from everything else", function()
	local kinds, sizes = {}, {}
	for _, den in World.dens do
		T.truthy(Creatures.byId[den.kind] ~= nil, den.kind)
		table.insert(kinds, den.kind)
		table.insert(sizes, den.count)
	end
	T.eq(kinds, {
		"brinehound",
		"brinehound",
		"brinehound",
		"brinehound",
		"shellback",
		"shellback",
		"shellback",
		"bogspitter",
		"bogspitter",
		"bogspitter",
		"brine_colossus",
	})
	T.eq(sizes, { 3, 3, 3, 3, 2, 2, 2, 2, 2, 2, 1 })
	local spots: { { name: string, at: Types.Vec3 } } = {}
	for _, cache in World.caches do
		table.insert(spots, { name = cache.id, at = cache.position })
	end
	for i, post in World.trainingPosts do
		table.insert(spots, { name = "post " .. i, at = post })
	end
	for trialId, position in World.wardens do
		table.insert(spots, { name = "warden " .. trialId, at = position })
	end
	for trialId, markers in World.courses do
		for i, marker in markers do
			table.insert(spots, { name = `{trialId} marker {i}`, at = marker })
		end
	end
	table.insert(spots, { name = "arena", at = World.duelArena })
	for i, den in World.dens do
		local p = den.position
		local label = `den {i} ({den.kind})`
		T.eq(p.y, 0, label)
		T.truthy(math.sqrt(p.x ^ 2 + p.z ^ 2) >= 330, label .. " in the wilds")
		T.truthy(Geography.regionAt(p.x, p.z) ~= "ReckoningRock", label)
		-- Its wander ring is quiet land with nothing solid at the den itself.
		T.truthy(quiet(p.x, p.z, 16), label .. " quiet")
		T.truthy(solidGap(p.x, p.z) >= 12, label .. " clear")
		for j, other in World.dens do
			if j ~= i then
				T.truthy(flat(p, other.position) >= 80, `{label} from den {j}`)
			end
		end
		for _, spot in spots do
			T.truthy(flat(p, spot.at) >= 80, `{label} from {spot.name}`)
		end
		for name, ledges in World.climbs do
			for _, ledge in ledges do
				T.truthy(flat(p, { x = ledge.x, y = 0, z = ledge.z }) >= 60, `{label} from {name}`)
			end
		end
	end
	-- Cull the Pack and Shellbreaker have their quarry within a short run of the Warden.
	T.truthy(flat(World.wardens.cull_the_pack, World.dens[1].position) <= 250)
	T.truthy(flat(World.wardens.shellbreaker, World.dens[5].position) <= 250)
end)

T.test("creature and champion ids", function()
	T.eq(World.CREATURE_ID_BASE, -2000000)
	T.eq(World.CHAMPION_ID_BASE, -3000000)
	T.eq(#World.creatureSlots, 25)
	T.eq(World.creatureSlots[1], { id = -2000001, den = 1, kind = "brinehound" })
	T.eq(World.creatureSlots[3], { id = -2000003, den = 1, kind = "brinehound" })
	T.eq(World.creatureSlots[4], { id = -2000004, den = 2, kind = "brinehound" })
	T.eq(World.creatureSlots[13], { id = -2000013, den = 5, kind = "shellback" })
	T.eq(World.creatureSlots[25], { id = -2000025, den = 11, kind = "brine_colossus" })
	T.eq({
		World.creatureIndex(-2000001) or 0,
		World.creatureIndex(-2000025) or 0,
		World.creatureIndex(-2000026) or 0,
		World.creatureIndex(-2000000) or 0,
		World.creatureIndex(-1) or 0,
		World.creatureIndex(-2000001.5) or 0,
		World.creatureIndex(0 / 0) or 0,
	}, { 1, 25, 0, 0, 0, 0, 0 })
	T.eq({
		World.isChampion(-3000001),
		World.isChampion(-3000250),
		World.isChampion(-3000000),
		World.isChampion(-3000001.5),
		World.isChampion(-1),
		World.isChampion(-2000001),
		World.isChampion(0 / 0),
		World.isChampion(-math.huge),
	}, { true, true, false, false, false, false, false, false })
	for _, slot in World.creatureSlots do
		T.eq(World.postIndex(slot.id), nil)
		T.falsy(World.isChampion(slot.id))
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
