--!strict
local T = require("./harness")
local B = require("../src/shared/Rules/CreatureBrain")
local Creatures = require("../src/shared/Catalog/Creatures")
local Geography = require("../src/shared/Rules/Geography")
local Types = require("../src/shared/Types")

type Vec3 = Types.Vec3

local hound = Creatures.byId.brinehound
local DEN: Vec3 = { x = 200, y = 0, z = 0 }

local function body(x: number, z: number, rooted: boolean?, den: Vec3?): B.Body
	return { position = { x = x, y = 0, z = z }, den = den or DEN, rooted = rooted == true }
end

local function seen(id: number, x: number, z: number, over: { [string]: any }?): B.Seen
	local s: { [string]: any } =
		{ id = id, position = { x = x, y = 0, z = z }, visible = true, valid = true }
	for k, v in over or {} do
		s[k] = v
	end
	return s :: any
end

-- Returns the given values in turn, then 0.
local function seq(...: number): () -> number
	local values = { ... }
	local i = 0
	return function()
		i += 1
		return values[i] or 0
	end
end

local function near(a: Vec3?, b: Vec3): boolean
	return a ~= nil
		and math.abs(a.x - b.x) < 1e-6
		and math.abs(a.y - b.y) < 1e-6
		and math.abs(a.z - b.z) < 1e-6
end

local function chasing(id: number): B.Brain
	local brain = B.new()
	brain.mode = "chase"
	brain.targetId = id
	return brain
end

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = copy(v)
	end
	return out
end

T.test("constants and a new brain", function()
	T.eq({
		B.TICK_SECONDS,
		B.WANDER_RADIUS,
		B.LEASH,
		B.HOME_RADIUS,
		B.TOWN_MARGIN,
		B.STOP_FRACTION,
	}, { 0.1, 12, 60, 3, 4, 0.6 })
	T.eq(
		B.new(),
		{ mode = "wander", targetId = 0, nextAttackAt = 0, nextLungeAt = 0, nextWanderAt = 0 }
	)
end)

T.test("wander: a new spot near the den every few seconds", function()
	local w = B.tick(hound, B.new(), body(200, 0), {}, nil, nil, 10, seq(0.25, 0.5, 0))
	T.truthy(near(w.moveTo, { x = 200, y = 0, z = 6 }))
	T.eq({ w.brain.mode, w.brain.nextWanderAt }, { "wander", 13 })
	T.eq({ w.home, w.action, w.faceTo }, { false, nil, nil })
	-- Not time yet: the same spot, and no draw.
	local again = B.tick(hound, w.brain, body(200, 3), {}, nil, nil, 12, seq(0.9, 0.9))
	T.truthy(near(again.moveTo, { x = 200, y = 0, z = 6 }))
	-- The delay is 3 to 6 seconds.
	T.eq(
		B.tick(hound, B.new(), body(200, 0), {}, nil, nil, 10, seq(0, 0, 1)).brain.nextWanderAt,
		16
	)
	for _ = 1, 200 do
		local d = B.tick(hound, B.new(), body(200, 0), {}, nil, nil, 0, math.random)
		local spot = d.brain.wanderTo :: Vec3
		T.truthy(math.sqrt((spot.x - 200) ^ 2 + spot.z ^ 2) <= 12)
	end
end)

T.test("noticing: the nearest valid player it can see within its sight", function()
	T.eq(
		B.tick(hound, B.new(), body(200, 0), { seen(7, 230, 0) }, nil, nil, 0, seq()).brain,
		{ mode = "chase", targetId = 7, nextAttackAt = 0, nextLungeAt = 0, nextWanderAt = 0 }
	)
	local function mode(list: { B.Seen }): string
		return B.tick(hound, B.new(), body(200, 0), list, nil, nil, 0, seq()).brain.mode
	end
	T.eq(mode({ seen(7, 236, 0) }), "wander", "sight 35")
	T.eq(mode({ seen(7, 220, 0, { visible = false }) }), "wander")
	T.eq(mode({ seen(7, 220, 0, { valid = false }) }), "wander")
	T.eq(
		B.tick(
			hound,
			B.new(),
			body(200, 0),
			{ seen(7, 225, 0), seen(8, 215, 0) },
			nil,
			nil,
			0,
			seq()
		).brain.targetId,
		8
	)
	-- Seen, but past the leash from the den: not a target.
	T.eq(
		B.tick(hound, B.new(), body(250, 0), { seen(7, 262, 0) }, nil, nil, 0, seq()).brain.mode,
		"wander"
	)
end)

T.test("chasing and biting: reach 5, every 1.4 s, stands within 3", function()
	local c = B.tick(hound, chasing(7), body(200, 0), { seen(7, 220, 0) }, nil, nil, 10, seq())
	T.eq(
		{ c.moveTo, c.faceTo, c.action },
		{ { x = 220, y = 0, z = 0 }, { x = 220, y = 0, z = 0 }, nil } :: { any }
	)
	local bite = B.tick(hound, chasing(7), body(200, 0), { seen(7, 204, 0) }, nil, nil, 10, seq())
	T.eq(
		{ bite.action, bite.brain.nextAttackAt, bite.moveTo },
		{ { kind = "attack", targetId = 7 }, 11.4, { x = 204, y = 0, z = 0 } } :: { any }
	)
	T.eq(
		B.tick(hound, bite.brain, body(200, 0), { seen(7, 204, 0) }, nil, nil, 11.3, seq()).action,
		nil
	)
	T.eq(
		B.tick(hound, bite.brain, body(200, 0), { seen(7, 204, 0) }, nil, nil, 11.4, seq()).action,
		{ kind = "attack", targetId = 7 }
	)
	T.eq(
		B.tick(hound, chasing(7), body(200, 0), { seen(7, 202.5, 0) }, nil, nil, 10, seq()).moveTo,
		nil
	)
	local high = seen(7, 204, 0, { position = { x = 204, y = 7, z = 0 } })
	T.eq(B.tick(hound, chasing(7), body(200, 0), { high }, nil, nil, 10, seq()).action, nil)
end)

T.test("giving up: past the leash, no longer valid, or gone", function()
	for _, list in { { seen(7, 261, 0) }, { seen(7, 220, 0, { valid = false }) }, {} } do
		local g = B.tick(hound, chasing(7), body(240, 0), list, nil, nil, 10, seq())
		T.eq({ g.brain.mode, g.brain.targetId, g.moveTo }, { "return", 0, DEN } :: { any })
		T.eq({ g.action, g.home }, { nil, false } :: { any })
	end
end)

T.test("returning ignores everyone, taunt included; home within 3", function()
	local back = chasing(0)
	back.mode = "return"
	local r1 = B.tick(hound, back, body(210, 0), { seen(7, 212, 0) }, 7, 7, 10, seq())
	T.eq({ r1.brain.mode, r1.moveTo, r1.home, r1.action }, { "return", DEN, false, nil } :: { any })
	local r2 = B.tick(hound, back, body(202.9, 0), {}, nil, nil, 10, seq())
	T.eq({ r2.brain.mode, r2.home, r2.moveTo }, { "wander", true, nil } :: { any })
	T.eq(r2.brain.nextWanderAt, 10)
end)

T.test("taunt and provocation", function()
	local two = { seen(7, 210, 0), seen(9, 220, 0) }
	T.eq(B.tick(hound, chasing(7), body(200, 0), two, 9, nil, 10, seq()).brain.targetId, 9)
	local invalid = { seen(7, 210, 0), seen(9, 220, 0, { valid = false }) }
	T.eq(B.tick(hound, chasing(7), body(200, 0), invalid, 9, nil, 10, seq()).brain.targetId, 7)
	local hidden9 = { seen(9, 250, 0, { visible = false }) }
	T.eq(B.tick(hound, B.new(), body(200, 0), hidden9, 9, nil, 10, seq()).brain.targetId, 9)
	-- An idle creature that is hit chases the hitter, seen or not.
	local hidden3 = { seen(3, 250, 0, { visible = false }) }
	T.eq(B.tick(hound, B.new(), body(200, 0), hidden3, nil, 3, 10, seq()).brain.targetId, 3)
	T.eq(
		B.tick(hound, B.new(), body(200, 0), { seen(3, 270, 0) }, nil, 3, 10, seq()).brain.mode,
		"wander",
		"70 from the den"
	)
	-- A creature already chasing keeps its target when someone else hits it (spec 3.12).
	T.eq(B.tick(hound, chasing(7), body(200, 0), two, nil, 9, 10, seq()).brain.targetId, 7)
	-- A taunt beats a hit.
	T.eq(B.tick(hound, B.new(), body(200, 0), two, 9, 7, 10, seq()).brain.targetId, 9)
end)

T.test("keep-away: the Bogspitter spits from 30 and backs off inside 15", function()
	local spit = Creatures.byId.bogspitter
	T.eq(
		B.tick(spit, chasing(7), body(200, 0), { seen(7, 210, 0) }, nil, nil, 10, seq()).moveTo,
		{ x = 195, y = 0, z = 0 }
	)
	local s25 = B.tick(spit, chasing(7), body(200, 0), { seen(7, 225, 0) }, nil, nil, 10, seq())
	T.eq({ s25.moveTo, s25.action }, { nil, { kind = "attack", targetId = 7 } } :: { any })
	T.eq(
		B.tick(spit, chasing(7), body(200, 0), { seen(7, 235, 0) }, nil, nil, 10, seq()).moveTo,
		{ x = 235, y = 0, z = 0 }
	)
	-- Standing on the target: it still backs off, along +x.
	T.eq(
		B.tick(spit, chasing(7), body(200, 0), { seen(7, 200, 0) }, nil, nil, 10, seq()).moveTo,
		{ x = 215, y = 0, z = 0 }
	)
end)

T.test("Slam within 10; Lunge between 7 and 12, every 8 s, not while rooted", function()
	local colossus = Creatures.byId.brine_colossus
	T.eq(
		B.tick(colossus, chasing(7), body(200, 0), { seen(7, 209, 0) }, nil, nil, 10, seq()).action,
		{ kind = "attack", targetId = 7 }
	)
	local tal = Creatures.byId.drowned_tallyman
	local l1 = B.tick(tal, chasing(7), body(200, 0), { seen(7, 210, 0) }, nil, nil, 10, seq())
	T.eq({ l1.action, l1.brain.nextLungeAt }, { { kind = "lunge", targetId = 7 }, 18 } :: { any })
	T.eq(B.tick(tal, l1.brain, body(200, 0), { seen(7, 210, 0) }, nil, nil, 17, seq()).action, nil)
	T.eq(
		B.tick(tal, chasing(7), body(200, 0), { seen(7, 205, 0) }, nil, nil, 10, seq()).action,
		{ kind = "attack", targetId = 7 }
	)
	T.eq(
		B.tick(tal, chasing(7), body(200, 0, true), { seen(7, 210, 0) }, nil, nil, 10, seq()).action,
		nil
	)
	T.eq(
		B.tick(tal, chasing(7), body(200, 0), { seen(7, 213, 0) }, nil, nil, 10, seq()).action,
		nil,
		"13 away"
	)
end)

T.test("Tallyport: no step ends inside the town or its 4-stud margin", function()
	T.eq(B.outsideTown({ x = 10, y = 2, z = 0 }), { x = 44, y = 2, z = 0 })
	T.eq(B.outsideTown({ x = 0, y = 0, z = 0 }), { x = 44, y = 0, z = 0 })
	T.eq(B.outsideTown({ x = 100, y = 0, z = 0 }), { x = 100, y = 0, z = 0 })
	T.truthy(near(B.outsideTown({ x = 0, y = 0, z = -20 }), { x = 0, y = 0, z = -44 }))
	local den = { x = 100, y = 0, z = 0 }
	T.eq(
		B.tick(hound, chasing(7), body(60, 0, false, den), { seen(7, 42, 0) }, nil, nil, 10, seq()).moveTo,
		{ x = 44, y = 0, z = 0 }
	)
end)

T.test("water: a creature stops at the bank instead of walking into a Sluice", function()
	-- The west Sluice: land at z = 64, water from z = 58.
	T.truthy(Geography.isLand(-400, 64))
	T.falsy(Geography.isLand(-400, 58))
	local den = { x = -400, y = 0, z = 80 }
	local onBridge = { seen(7, -400, 30) }
	local d = B.tick(hound, chasing(7), body(-400, 64, false, den), onBridge, nil, nil, 10, seq())
	T.eq(
		{ d.brain.mode, d.moveTo, d.faceTo },
		{ "chase", nil, { x = -400, y = 0, z = 30 } } :: { any }
	)
	-- Away from the bank it still walks.
	local far = B.tick(hound, chasing(7), body(-400, 80, false, den), onBridge, nil, nil, 10, seq())
	T.eq(far.moveTo, { x = -400, y = 0, z = 30 })
end)

T.test("tick never changes its arguments", function()
	local brain, b = chasing(7), body(200, 0)
	local list = { seen(7, 204, 0), seen(9, 220, 0) }
	local brain0, b0, list0 = copy(brain), copy(b), copy(list)
	B.tick(hound, brain, b, list, 9, 7, 10, seq(0.3, 0.4, 0.5))
	B.tick(hound, B.new(), b, {}, nil, nil, 10, seq(0.3, 0.4, 0.5))
	T.eq({ brain, b, list }, { brain0, b0, list0 } :: { any })
	local wander = B.new()
	B.tick(hound, wander, b, {}, nil, nil, 10, seq(0.3, 0.4, 0.5))
	T.eq(wander, B.new())
end)

T.test("a creature that cannot get home is sent home after the return limit", function()
	T.eq(B.RETURN_TIMEOUT, 8)
	-- The west bank: the way to this den crosses the Sluice, so every step is blocked.
	local den = { x = -400, y = 0, z = 30 }
	local stuck = body(-400, 64, false, den)
	local brain = B.new()
	brain.mode = "return"
	for now = 10, 17 do
		local d = B.tick(hound, brain, stuck, {}, nil, nil, now, seq())
		T.eq(
			{ d.moveTo, d.home, d.snapHome, d.brain.mode },
			{ nil, false, false, "return" } :: { any },
			`still trying at {now}`
		)
		brain = d.brain
	end
	local d = B.tick(hound, brain, stuck, {}, nil, nil, 18, seq())
	T.eq(
		{ d.home, d.snapHome, d.brain.mode, d.brain.targetId, d.moveTo, d.action },
		{ true, true, "wander", 0, nil, nil } :: { any }
	)
	T.eq(d.brain.nextWanderAt, 18)
	T.eq(d.brain.returnSince, nil)
end)

T.test("a creature that keeps getting closer is never snapped home", function()
	local brain = B.new()
	brain.mode = "return"
	for now = 10, 40 do
		local d = B.tick(hound, brain, body(100 + (now - 10) * 3, 0), {}, nil, nil, now, seq())
		T.eq({ d.home, d.snapHome, d.brain.mode }, { false, false, "return" } :: { any })
		brain = d.brain
	end
end)

T.test(
	"the return limit counts from the last progress, and an ordinary arrival does not snap",
	function()
		local brain = B.new()
		brain.mode = "return"
		local at = body(100, 0)
		local d = B.tick(hound, brain, at, {}, nil, nil, 10, seq())
		-- Stuck for 7 s, then a real step closer: the clock starts again.
		d = B.tick(hound, d.brain, at, {}, nil, nil, 17, seq())
		T.eq(d.snapHome, false)
		d = B.tick(hound, d.brain, body(110, 0), {}, nil, nil, 17.5, seq())
		d = B.tick(hound, d.brain, body(110, 0), {}, nil, nil, 25, seq())
		T.eq({ d.home, d.snapHome }, { false, false } :: { any })
		d = B.tick(hound, d.brain, body(110, 0), {}, nil, nil, 25.5, seq())
		T.eq({ d.home, d.snapHome }, { true, true } :: { any })
		local back = B.new()
		back.mode = "return"
		local home = B.tick(hound, back, body(201, 0), {}, nil, nil, 30, seq())
		T.eq({ home.home, home.snapHome }, { true, false } :: { any })
	end
)

T.test("the return limit does not change the brain it is given", function()
	local brain = B.new()
	brain.mode = "return"
	brain.returnSince = 1
	brain.returnBest = 50
	local before = copy(brain)
	B.tick(hound, brain, body(100, 0), {}, nil, nil, 30, seq())
	B.tick(hound, brain, body(100, 0), {}, nil, nil, 3, seq())
	T.eq(brain, before)
end)
