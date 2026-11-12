--!strict
local T = require("./harness")
local Geography = require("../src/shared/Rules/Geography")
local Looks = require("../src/shared/Catalog/Looks")
local Regions = require("../src/shared/Catalog/Regions")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.01
end

T.test("bearings and frames", function()
	T.eq(Geography.bearingOf(0, -100), 0)
	T.truthy(near(Geography.bearingOf(100, 0), 90))
	T.truthy(near(Geography.bearingOf(0, 100), 180))
	T.truthy(near(Geography.bearingOf(-100, 0), 270))
	T.eq(Geography.bearingOf(0, 0), 0)
	local x, z = Geography.place("Thornwood", 500, 100)
	T.truthy(near(x, 100) and near(z, -500))
	x, z = Geography.place("DrownedFen", 500, 100)
	T.truthy(near(x, -100) and near(z, 500))
	x, z = Geography.place("SquallSteps", 400, 0)
	T.truthy(near(x, 346.41) and near(z, -200))
	x, z = Geography.place("BastionReach", 820, 0)
	T.truthy(near(x, -710.14) and near(z, -410))
	local along, across = Geography.toFrame(60, 346.41, -200)
	T.truthy(near(along, 400) and near(across, 0))
	T.falsy(pcall(Geography.place, "Tallyport", 10, 0))
end)

T.test("coast", function()
	T.truthy(near(Geography.coastRadius(0), 993.66))
	T.truthy(near(Geography.coastRadius(120), 924.45))
	T.truthy(near(Geography.coastRadius(180), 926.34))
end)

T.test("regions by position", function()
	T.eq(Geography.regionAt(0, 0), "Tallyport")
	T.eq(Geography.regionAt(39, 0), "Tallyport")
	T.eq(Geography.regionAt(60, 40), "CountingFields")
	T.eq(Geography.regionAt(0, -600), "Thornwood")
	T.eq(Geography.regionAt(520, -300), "SquallSteps")
	T.eq(Geography.regionAt(520, 300), "CinderFlats")
	T.eq(Geography.regionAt(0, 600), "DrownedFen")
	T.eq(Geography.regionAt(-520, 300), "HushGardens")
	T.eq(Geography.regionAt(-520, -300), "BastionReach")
	T.eq(Geography.regionAt(0, 1240), "ReckoningRock")
	T.eq(Geography.regionAt(0, 1000), "ReckoningRock") -- the causeway
	T.eq(Geography.regionAt(0, 920), "DrownedFen")
end)

T.test("land and sea", function()
	T.truthy(Geography.isLand(0, 0))
	T.truthy(Geography.isLand(0, -600))
	T.falsy(Geography.isLand(2000, 0))
	T.falsy(Geography.isLand(-320, 0)) -- the west river
	T.truthy(Geography.isLand(-280, 0)) -- rivers start 300 out
	T.truthy(Geography.isLand(0, 1000)) -- causeway
	T.falsy(Geography.isLand(60, 1000)) -- sea beside it
	T.truthy(Geography.isLand(0, 1240))
	T.falsy(Geography.cellIsLand(35, 0))
end)

T.test("non-finite positions read as Fields and as not land", function()
	local nan = 0 / 0
	T.eq(Geography.regionAt(nan, 0), "CountingFields")
	T.eq(Geography.regionAt(0, math.huge), "CountingFields")
	T.falsy(Geography.isLand(nan, 0))
	T.falsy(Geography.isLand(0, -math.huge))
end)

T.test("everything within 270 of the centre is land", function()
	for x = -270, 270, 10 do
		for z = -270, 270, 10 do
			if x * x + z * z <= 270 * 270 then
				T.truthy(Geography.isLand(x, z), x .. "," .. z)
			end
		end
	end
end)

T.test("strips cover every land cell once", function()
	local strips = Geography.strips()
	T.eq(#strips, 144)
	local cells: { [string]: number } = {}
	local total = 0
	for _, s in strips do
		T.truthy(s.x2 > s.x1)
		local n = (s.x2 - s.x1) / 40
		T.eq(n, math.floor(n))
		total += n
		cells[s.region] = (cells[s.region] or 0) + n
		for x = s.x1 + 20, s.x2 - 20, 40 do
			T.truthy(Geography.isLand(x, s.z))
			local i, j = Geography.cellOf(x, s.z)
			T.eq(Geography.cellRegion(i, j), s.region)
		end
	end
	T.eq(total, 1695)
	T.eq(cells, {
		CountingFields = 137,
		Thornwood = 265,
		SquallSteps = 251,
		CinderFlats = 261,
		DrownedFen = 252,
		ReckoningRock = 18,
		HushGardens = 252,
		BastionReach = 259,
	})
end)

T.test("land is one connected piece and rivers split their regions", function()
	-- Flood fill over 4-neighbour land cells from (0, 0) must reach all 1695.
	local grid = Geography.GRID
	local function key(i: number, j: number): number
		return (i + grid) * (2 * grid + 1) + (j + grid)
	end
	local seen: { [number]: boolean } = { [key(0, 0)] = true }
	local queue: { { number } } = { { 0, 0 } }
	local head = 1
	local reached = 0
	while head <= #queue do
		local cell = queue[head]
		head += 1
		reached += 1
		for _, step in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ni, nj = cell[1] + step[1], cell[2] + step[2]
			if Geography.cellIsLand(ni, nj) and not seen[key(ni, nj)] then
				seen[key(ni, nj)] = true
				table.insert(queue, { ni, nj })
			end
		end
	end
	T.eq(reached, 1695)

	-- No land cell of Thornwood/CinderFlats/HushGardens whose centre is 340 or more from the
	-- island centre has an 8-neighbour land cell of SquallSteps/DrownedFen/BastionReach
	-- respectively.
	local across: { [string]: string } = {
		Thornwood = "SquallSteps",
		CinderFlats = "DrownedFen",
		HushGardens = "BastionReach",
	}
	local checked = 0
	for i = -grid, grid do
		for j = -grid, grid do
			if not Geography.cellIsLand(i, j) then
				continue
			end
			local other = across[Geography.cellRegion(i, j)]
			if other == nil or math.sqrt((40 * i) ^ 2 + (40 * j) ^ 2) < 340 then
				continue
			end
			checked += 1
			for di = -1, 1 do
				for dj = -1, 1 do
					if (di ~= 0 or dj ~= 0) and Geography.cellIsLand(i + di, j + dj) then
						T.truthy(
							Geography.cellRegion(i + di, j + dj) ~= other,
							`river does not split cell {i},{j} from {i + di},{j + dj}`
						)
					end
				end
			end
		end
	end
	T.truthy(checked > 0, "some far cells were checked")
end)

T.test("six bridges land on both banks", function()
	local bridges = Geography.bridges()
	T.eq(#bridges, 6)
	for _, b in bridges do
		T.eq(b.length, 180)
		T.eq(b.width, 16)
		-- The two points 85 studs either side of the centre along the yaw bearing are land
		-- and lie in two different regions.
		local t = math.rad(b.yaw)
		local dx, dz = 85 * math.sin(t), -85 * math.cos(t)
		local x1, z1 = b.x - dx, b.z - dz
		local x2, z2 = b.x + dx, b.z + dz
		T.truthy(Geography.isLand(x1, z1), `bridge at {b.x},{b.z} near end is land`)
		T.truthy(Geography.isLand(x2, z2), `bridge at {b.x},{b.z} far end is land`)
		T.truthy(
			Geography.regionAt(x1, z1) ~= Geography.regionAt(x2, z2),
			`bridge at {b.x},{b.z} joins two regions`
		)
	end
end)

T.test("shape helpers", function()
	local c = Geography.circle("Thornwood", 500, 100, 14)
	T.eq(c.kind, "circle")
	T.truthy(near(c.x, 100) and near(c.z, -500))
	T.eq(c.radius, 14)
	local r = Geography.rect("DrownedFen", 400, 860, -180, 200)
	T.eq(r.kind, "rect")
	T.eq(r.bearing, 180)
	T.eq(r.halfAlong, 230)
	T.eq(r.halfAcross, 190)
	T.truthy(near(r.x, -10) and near(r.z, 630))
	local g = Geography.regionShape("HushGardens", 330)
	T.eq(g, {
		kind = "region",
		x = 0,
		z = 0,
		radius = 330,
		bearing = 0,
		halfAlong = 0,
		halfAcross = 0,
		region = "HushGardens",
	})
end)

T.test("regions and looks", function()
	T.eq(#Regions.list, 9)
	T.eq(
		Regions.wild,
		{ "Thornwood", "SquallSteps", "CinderFlats", "DrownedFen", "HushGardens", "BastionReach" }
	)
	for i, id in Regions.wild do
		T.eq(Regions.byId[id].bearing, (i - 1) * 60)
	end
	for _, region in Regions.list do
		T.truthy(Looks.byName[region.ground] ~= nil, region.id)
		T.truthy(#region.hint > 0)
	end
	T.eq(Regions.byId.SquallSteps.name, "Squall Steps")
	T.eq(Looks.byName.lava, { r = 255, g = 110, b = 20, material = "Neon", transparency = 0.1 })
end)
