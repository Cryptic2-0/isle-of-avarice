--!strict
local T = require("./harness")
local Geography = require("../src/shared/Rules/Geography")
local Hazards = require("../src/shared/Rules/Hazards")
local Looks = require("../src/shared/Catalog/Looks")
local Make = require("../src/shared/Catalog/SiteData/Make")
local Relics = require("../src/shared/Catalog/Relics")
local Sites = require("../src/shared/Catalog/Sites")
local SquallSteps = require("../src/shared/Catalog/SiteData/SquallSteps")
local Thornwood = require("../src/shared/Catalog/SiteData/Thornwood")
local Types = require("../src/shared/Types")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.001
end

local function isFinite(n: number): boolean
	return n > -math.huge and n < math.huge
end

-- The footprint of a block feature as a rect shape.
local function footprint(feature: Types.Feature): Types.Shape
	return {
		kind = "rect",
		x = feature.x,
		z = feature.z,
		radius = 0,
		bearing = feature.yaw,
		halfAlong = feature.sz / 2,
		halfAcross = feature.sx / 2,
		region = "",
	}
end

T.test("every hazard is well formed and sits on land in its own region", function()
	local seen: { [string]: boolean } = {}
	for _, site in Sites.list do
		for _, h in site.hazards do
			T.falsy(seen[h.id], h.id .. " is unique")
			seen[h.id] = true
			T.eq(Sites.hazardById[h.id], h)
			T.eq(h.region, site.region, h.id)
			T.truthy(Looks.byName[h.look] ~= nil, h.id .. " look")
			T.truthy(
				h.dps ~= nil or h.damage ~= nil or h.heal ~= nil or h.slow ~= nil or h.push ~= nil,
				h.id .. " has an effect"
			)
			if h.shape.kind ~= "region" then
				T.truthy(Geography.isLand(h.shape.x, h.shape.z), h.id .. " on land")
				T.eq(Geography.regionAt(h.shape.x, h.shape.z), site.region, h.id .. " region")
			end
			if h.cycle ~= nil then
				T.truthy(h.cycle.period > 0 and h.cycle.warn >= 0 and h.cycle.active > 0, h.id)
				T.truthy(h.cycle.warn + h.cycle.active < h.cycle.period, h.id)
			end
			if h.slow ~= nil then
				T.truthy(h.slow > 0 and h.slow < 1, h.id)
			end
		end
	end
end)

T.test("every feature is well formed", function()
	for _, site in Sites.list do
		for i, f in site.features do
			local label = `{site.region} feature {i}`
			T.truthy(Looks.byName[f.look] ~= nil, label .. " look")
			T.truthy(f.shape == "block" or f.shape == "cylinder", label .. " shape")
			T.truthy(f.sx > 0 and isFinite(f.sx), label .. " sx")
			T.truthy(f.sy > 0 and isFinite(f.sy), label .. " sy")
			T.truthy(f.sz > 0 and isFinite(f.sz), label .. " sz")
			T.truthy(isFinite(f.x) and isFinite(f.y) and isFinite(f.z), label .. " position")
			T.truthy(isFinite(f.yaw), label .. " yaw")
		end
	end
end)

T.test("every prize is a known Relic on land in its region and can be held", function()
	for _, site in Sites.list do
		local prize = site.prize
		if prize ~= nil then
			T.truthy(Relics.byId[prize.relicId] ~= nil)
			T.truthy(Geography.isLand(prize.x, prize.z))
			T.eq(Geography.regionAt(prize.x, prize.z), site.region)
			local hold = prize.hold or 0.5
			for _, h in Sites.hazards do
				if (h.dps ~= nil or h.damage ~= nil) and Hazards.affects(h, prize.x, prize.z) then
					if h.cycle == nil then
						T.eq(h.shape.kind, "region", h.id .. " always hurts at the prize")
					else
						local quiet = h.cycle.period - h.cycle.active
						T.truthy(quiet >= hold + 0.5, h.id .. " leaves time to open the prize")
					end
				end
			end
		end
	end
end)

T.test("Make.block and Make.disc build features from region-frame measurements", function()
	local x, z = Geography.place("SquallSteps", 500, 10)
	local block = Make.block("SquallSteps", 490, 510, 0, 20, 0, 6, "pillar", true)
	T.eq(block, {
		look = "pillar",
		shape = "block",
		x = x,
		y = 3,
		z = z,
		sx = 20,
		sy = 6,
		sz = 20,
		yaw = 60,
		solid = true,
	})
	local wide = Make.block("Thornwood", 480, 500, -30, 50, 2, 14, "hedge", false)
	T.eq({ wide.sx, wide.sy, wide.sz, wide.y, wide.yaw, wide.solid }, { 80, 12, 20, 8, 0, false })
	x, z = Geography.place("Thornwood", 485, 10)
	T.truthy(Hazards.contains(footprint(wide), x, z))
	x, z = Geography.place("Thornwood", 485, 51)
	T.falsy(Hazards.contains(footprint(wide), x, z))

	x, z = Geography.place("SquallSteps", 700, -20)
	T.eq(Make.disc("SquallSteps", 700, -20, 5, 1, 9, "rock", false), {
		look = "rock",
		shape = "cylinder",
		x = x,
		y = 5,
		z = z,
		sx = 10,
		sy = 8,
		sz = 10,
		yaw = 60,
		solid = false,
	})
end)

-- Steps from the first square to the second, moving between squares that share a side and
-- stepping only on the given characters. nil when there is no way.
local function steps(
	maze: { string },
	from: { number },
	to: { number },
	passable: { [string]: boolean }
): number?
	local dist: { [number]: number } = {}
	local function key(r: number, c: number): number
		return r * 100 + c
	end
	local queue: { { number } } = { from }
	dist[key(from[1], from[2])] = 0
	local head = 1
	while head <= #queue do
		local r, c = queue[head][1], queue[head][2]
		head += 1
		if r == to[1] and c == to[2] then
			return dist[key(r, c)]
		end
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nr, nc = r + d[1], c + d[2]
			local row = maze[nr]
			if row ~= nil and nc >= 1 and nc <= #row and dist[key(nr, nc)] == nil then
				if passable[string.sub(row, nc, nc)] then
					dist[key(nr, nc)] = dist[key(r, c)] + 1
					table.insert(queue, { nr, nc })
				end
			end
		end
	end
	return nil
end

T.test("Thornwood maze", function()
	local maze = Thornwood.MAZE
	T.eq(#maze, 17)
	for _, row in maze do
		T.eq(#row, 17)
	end
	local along, across = Thornwood.cellCentre(9, 9)
	T.eq({ along, across }, { 650, 0 })
	T.eq({ Thornwood.cellCentre(1, 8) }, { 490, -20 })

	-- Steps from each entrance to the P square, moving between squares that share a side:
	-- through "." and "P" only, then also allowing "b".
	local goal: { number } = {}
	for r, row in maze do
		local c = string.find(row, "P", 1, true)
		if c ~= nil then
			goal = { r, c }
		end
	end
	T.eq(goal, { 9, 9 })
	local south, west, east = { 1, 8 }, { 8, 1 }, { 10, 17 }
	local dry = { ["."] = true, P = true }
	local brier = { ["."] = true, P = true, b = true }
	T.eq(steps(maze, south, goal, dry), 93)
	T.eq(steps(maze, west, goal, dry), 77)
	T.eq(steps(maze, east, goal, dry), 49)
	T.eq(steps(maze, south, goal, brier), 17)
	T.eq(steps(maze, west, goal, brier), 13)
	T.eq(steps(maze, east, goal, brier), 17)

	-- Every "#" square's centre lies inside exactly one solid hedge feature's footprint and
	-- every other square's centre lies in none. Every "b" square's centre is affected by
	-- exactly one ThornBriar hazard (numbered in row-then-column order) and every other
	-- square's centre by none.
	for _, f in Thornwood.features do
		T.truthy(
			f.solid and f.look == "hedge" and f.shape == "block",
			"every feature is solid hedge"
		)
		T.eq({ f.y - f.sy / 2, f.y + f.sy / 2 }, { 0, 14 }, "hedge runs from y 0 to 14")
	end
	local briars = 0
	for r, row in maze do
		for c = 1, #row do
			local char = string.sub(row, c, c)
			local sx, sz = Thornwood.cellCentre(r, c)
			local x, z = Geography.place("Thornwood", sx, sz)
			local label = `square ({r}, {c})`

			local hedges = 0
			for _, f in Thornwood.features do
				if Hazards.contains(footprint(f), x, z) then
					hedges += 1
				end
			end
			T.eq(hedges, if char == "#" then 1 else 0, label .. " hedges")

			local affecting: { Types.Hazard } = {}
			for _, h in Thornwood.hazards do
				if Hazards.affects(h, x, z) then
					table.insert(affecting, h)
				end
			end
			if char == "b" then
				briars += 1
				T.eq(#affecting, 1, label .. " briars")
				T.eq(affecting[1].id, "ThornBriar" .. briars, label)
				T.eq(affecting[1].dps, 12, label)
				T.eq(affecting[1].slow, 0.6, label)
			else
				T.eq(#affecting, 0, label .. " is not briared")
			end
		end
	end
	T.eq(briars, 6)

	T.eq(#Thornwood.hazards, 12)
	T.eq(Thornwood.region, "Thornwood")
	local thickets = {
		{ 350, -100 },
		{ 380, 110 },
		{ 420, -150 },
		{ 440, 60 },
		{ 455, -60 },
		{ 415, -35 },
	}
	for i, at in thickets do
		local h = Thornwood.hazards[6 + i]
		T.eq(h.id, "ThornThicket" .. i)
		T.eq(h.shape, Geography.circle("Thornwood", at[1], at[2], 14), h.id)
	end
	for i, h in Thornwood.hazards do
		T.eq(h.name, "Briars", h.id)
		T.eq(h.look, "briar", h.id)
		T.eq({ h.dps, h.slow }, { 12, 0.6 }, h.id)
		T.falsy(h.cycle, h.id)
		T.falsy(h.holes, h.id)
		if i <= 6 then
			T.eq(h.id, "ThornBriar" .. i)
			T.eq(h.shape.kind, "rect", h.id)
		end
	end

	local px, pz = Geography.place("Thornwood", 650, 0)
	T.eq(Thornwood.prize, { relicId = "R009", x = px, y = 1, z = pz, hold = 3 })
	T.eq(Thornwood.keepOut, { Geography.rect("Thornwood", 480, 820, -170, 170) })
end)

T.test("Squall Steps climb", function()
	T.eq(SquallSteps.region, "SquallSteps")
	T.eq(#SquallSteps.pillars, 18)
	for k, p in SquallSteps.pillars do
		T.eq(p.top, 3 * k)
		T.eq(p.along, 480 + 19 * (k - 1))
		T.eq(p.across, if k % 2 == 1 then 6 else -6)
	end

	-- 19 features: 18 pillars 14 wide and the summit; pillar k's feature has sy = 3k and y = 1.5k.
	T.eq(#SquallSteps.features, 19)
	for k, p in SquallSteps.pillars do
		local f = SquallSteps.features[k]
		local x, z = Geography.place("SquallSteps", p.along, p.across)
		T.eq(f, {
			look = "pillar",
			shape = "block",
			x = x,
			y = 1.5 * k,
			z = z,
			sx = 14,
			sy = 3 * k,
			sz = 14,
			yaw = 60,
			solid = true,
		})
	end
	local summit = SquallSteps.features[19]
	local sumX, sumZ = Geography.place("SquallSteps", 845, 0)
	T.eq(summit, {
		look = "pillar",
		shape = "block",
		x = sumX,
		y = 28.5,
		z = sumZ,
		sx = 60,
		sy = 57,
		sz = 60,
		yaw = 60,
		solid = true,
	})

	T.eq(#SquallSteps.hazards, 4)
	local lanes = {
		{ 530, 600, -40, 40 },
		{ 625, 695, -40, 40 },
		{ 720, 790, -40, 40 },
		{ 815, 875, -30, 30 },
	}
	for i, h in SquallSteps.hazards do
		T.eq(h.id, "SquallGust" .. i)
		T.eq(h.region, "SquallSteps", h.id)
		T.eq(h.name, "Gust", h.id)
		T.eq(h.look, "gust", h.id)
		local lane = lanes[i]
		T.eq(h.shape, Geography.rect("SquallSteps", lane[1], lane[2], lane[3], lane[4]), h.id)
		local push = h.push :: { x: number, z: number }
		T.truthy(math.abs(math.sqrt(push.x ^ 2 + push.z ^ 2) - 11) < 0.001, h.id)
		T.eq(h.cycle, {
			period = 7,
			warn = 1.5,
			active = 2,
			offset = ({ 0, 2.3, 4.6, 1.2 })[tonumber(string.sub(h.id, -1)) :: number],
		})
	end

	-- SquallGust1 pushes toward +across: toFrame(60, push.x, push.z) is about (0, 11).
	-- SquallGust2 about (0, -11); SquallGust3 about (0, 11); SquallGust4 about (11, 0), markerY 57.2.
	local expected = { { 0, 11 }, { 0, -11 }, { 0, 11 }, { 11, 0 } }
	for i, h in SquallSteps.hazards do
		local push = h.push :: { x: number, z: number }
		local along, across = Geography.toFrame(60, push.x, push.z)
		T.truthy(near(along, expected[i][1]) and near(across, expected[i][2]), h.id .. " push")
		T.eq(h.markerY, if i == 4 then 57.2 else nil, h.id)
	end

	-- Lanes 1 to 3 each affect exactly 4 pillar centres.
	for i = 1, 3 do
		local affected = 0
		for _, p in SquallSteps.pillars do
			local x, z = Geography.place("SquallSteps", p.along, p.across)
			if Hazards.affects(SquallSteps.hazards[i], x, z) then
				affected += 1
			end
		end
		T.eq(affected, 4, SquallSteps.hazards[i].id)
	end

	local px, pz = Geography.place("SquallSteps", 845, 0)
	T.eq(SquallSteps.prize, { relicId = "R007", x = px, y = 58, z = pz, hold = 3 })
	T.eq(SquallSteps.keepOut, { Geography.rect("SquallSteps", 470, 880, -45, 45) })
end)

T.test("Sites gathers the sites", function()
	T.eq(Sites.list[1].region, "Thornwood")
	T.eq(Sites.list[2].region, "SquallSteps")
	local hazardCount, featureCount = 0, 0
	local hazards: { Types.Hazard } = {}
	local features: { Types.Feature } = {}
	for _, site in Sites.list do
		hazardCount += #site.hazards
		featureCount += #site.features
		for _, h in site.hazards do
			table.insert(hazards, h)
		end
		for _, f in site.features do
			table.insert(features, f)
		end
	end
	T.eq(#Sites.hazards, hazardCount)
	T.eq(#Sites.features, featureCount)
	-- both gather in list order
	for i, h in hazards do
		T.truthy(Sites.hazards[i] == h, `hazard {i} is in list order`)
	end
	for i, f in features do
		T.truthy(Sites.features[i] == f, `feature {i} is in list order`)
	end
end)
