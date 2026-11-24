--!strict
local T = require("./harness")
local Geography = require("../src/shared/Rules/Geography")
local Hazards = require("../src/shared/Rules/Hazards")
local Types = require("../src/shared/Types")

-- A hazard with id, region, name and look filled in; any field passed overrides the default.
local function hz(fields: { [string]: any }): Types.Hazard
	local hazard: { [string]: any } =
		{ id = "h", region = "CinderFlats", name = "Hazard", look = "none" }
	for key, value in fields do
		hazard[key] = value
	end
	return hazard :: any
end

local pool = hz({
	id = "pool",
	name = "Lava",
	dps = 30,
	shape = Geography.circle("CinderFlats", 500, 0, 20),
})
local px, pz = Geography.place("CinderFlats", 500, 0)

T.test("circle, rect and region shapes", function()
	T.truthy(Hazards.contains(pool.shape, px + 19, pz))
	T.falsy(Hazards.contains(pool.shape, px + 21, pz))
	local rect = Geography.rect("SquallSteps", 530, 600, -40, 40)
	local x, z = Geography.place("SquallSteps", 599, 39)
	T.truthy(Hazards.contains(rect, x, z))
	x, z = Geography.place("SquallSteps", 601, 0)
	T.falsy(Hazards.contains(rect, x, z))
	x, z = Geography.place("SquallSteps", 560, 41)
	T.falsy(Hazards.contains(rect, x, z))
	local blight = Geography.regionShape("HushGardens", 330)
	x, z = Geography.place("HushGardens", 500, 60)
	T.truthy(Hazards.contains(blight, x, z))
	x, z = Geography.place("HushGardens", 300, 0)
	T.falsy(Hazards.contains(blight, x, z))
	T.falsy(Hazards.contains(blight, 0, -600)) -- Thornwood
end)

T.test("holes", function()
	local lake = hz({
		id = "lake",
		dps = 30,
		shape = Geography.circle("CinderFlats", 760, 0, 110),
		holes = {
			Geography.circle("CinderFlats", 760, 0, 32),
			Geography.rect("CinderFlats", 650, 730, -10, 10),
		},
	})
	local function at(along: number, across: number): boolean
		return Hazards.affects(lake, Geography.place("CinderFlats", along, across))
	end
	T.truthy(at(760, 60))
	T.falsy(at(760, 0))
	T.falsy(at(700, 5))
	T.truthy(at(700, 15))
	T.falsy(at(600, 0))
end)

T.test("phases", function()
	local tide = hz({
		id = "tide",
		dps = 40,
		cycle = { period = 120, warn = 15, active = 35, offset = 0 },
		shape = pool.shape,
	})
	local phase, cycle, part = Hazards.phase(tide, 0)
	T.eq({ phase, cycle, part }, { "idle", 0, 0 })
	T.eq((Hazards.phase(tide, 69.9)), "idle")
	phase, cycle, part = Hazards.phase(tide, 77.5)
	T.eq({ phase, cycle, part }, { "warn", 0, 0.5 })
	T.eq((Hazards.phase(tide, 85)), "active")
	T.eq((Hazards.phase(tide, 119.9)), "active")
	phase, cycle = Hazards.phase(tide, 120)
	T.eq({ phase, cycle }, { "idle", 1 })
	local late = hz({
		id = "late",
		damage = 35,
		cycle = { period = 6, warn = 1.5, active = 1, offset = 2.4 },
		shape = pool.shape,
	})
	T.eq((Hazards.phase(late, 0)), "idle") -- t = 2.4 < 3.5
	T.eq((Hazards.phase(late, 1.2)), "warn") -- t = 3.6
	phase, cycle = Hazards.phase(late, 3.0) -- t = 5.4
	T.eq({ phase, cycle }, { "active", 0 })
	phase, cycle = Hazards.phase(late, 9.0) -- t = 11.4 -> 5.4 of cycle 1
	T.eq({ phase, cycle }, { "active", 1 })
	T.eq({ Hazards.phase(pool, 12345) }, { "active", 0, 0 })
	T.eq({ Hazards.phase(tide, 0 / 0) }, { "idle", 0, 0 })
	T.eq({ Hazards.phase(tide, math.huge) }, { "idle", 0, 0 })
end)

T.test("sample adds effects and reports bursts once per cycle index", function()
	local spring = hz({ id = "spring", name = "Spring", heal = 15, shape = pool.shape })
	local bog = hz({ id = "bog", name = "Bog", slow = 0.5, dps = 3, shape = pool.shape })
	local briar = hz({ id = "briar", name = "Briars", slow = 0.6, dps = 12, shape = pool.shape })
	local gust =
		hz({ id = "gust", name = "Gust", push = { x = 5.5, z = 9.53 }, shape = pool.shape })
	local vent = hz({
		id = "vent",
		name = "Vent",
		damage = 35,
		cycle = { period = 6, warn = 1.5, active = 1, offset = 0 },
		shape = pool.shape,
	})
	local list = { pool, spring, bog, briar, gust, vent }
	T.eq(Hazards.sample(list, px, pz, 0), {
		dps = 45,
		heal = 15,
		slow = 0.5,
		pushX = 5.5,
		pushZ = 9.53,
		bursts = {},
		names = { "Lava", "Spring", "Bog", "Briars", "Gust" },
	})
	local s = Hazards.sample(list, px, pz, 5.2)
	T.eq(s.bursts, { { id = "vent", damage = 35, cycle = 0 } })
	T.eq(s.names[6], "Vent")
	T.eq(Hazards.sample(list, px, pz, 5.9).bursts[1].cycle, 0)
	T.eq(Hazards.sample(list, px, pz, 11.2).bursts[1].cycle, 1)
	T.eq(#Hazards.sample(list, px, pz, 4).bursts, 0) -- warning only
end)

T.test("outside everything, and non-finite input, give the empty sample", function()
	local empty = { dps = 0, heal = 0, slow = 1, pushX = 0, pushZ = 0, bursts = {}, names = {} }
	T.eq(Hazards.sample({ pool }, 0, 0, 0), empty)
	T.eq(Hazards.sample({ pool }, 0 / 0, pz, 0), empty)
	T.eq(Hazards.sample({ pool }, px, math.huge, 0), empty)
	T.eq(Hazards.sample({}, px, pz, 0), empty)
end)

T.test("same name from two hazards is listed once", function()
	local a = hz({ id = "a", name = "Lava", dps = 30, shape = pool.shape })
	T.eq(Hazards.sample({ pool, a }, px, pz, 0).names, { "Lava" })
	T.eq(Hazards.sample({ pool, a }, px, pz, 0).dps, 60)
end)
