--!strict
local T = require("./harness")
local Combat = require("../src/shared/Rules/Combat")
local Targeting = require("../src/shared/Rules/Targeting")

local me = { id = 1, position = { x = 0, y = 0, z = 0 }, look = { x = 0, y = 0, z = -1 } }
local blind = { id = 1, position = me.position, look = { x = 0, y = 0, z = 0 } }

local function at(id: number, x: number, y: number, z: number): Combat.Fighter
	return { id = id, position = { x = x, y = y, z = z }, look = { x = 0, y = 0, z = 1 } }
end

T.test("ahead projects horizontally and keeps y", function()
	T.eq(Targeting.ahead(me, 25), { x = 0, y = 0, z = -25 })
	local tilted = { id = 1, position = { x = 1, y = 3, z = 2 }, look = { x = 3, y = 9, z = 0 } }
	T.eq(Targeting.ahead(tilted, 10), { x = 11, y = 3, z = 2 })
end)

T.test("shot hits along the ray within range and radius", function()
	T.eq(Targeting.shot(me, { at(2, 0, 0, -30) }, 35, 0), 2)
	T.eq(Targeting.shot(me, { at(2, 0, 0, -36) }, 35, 0), nil)
	T.eq(Targeting.shot(me, { at(2, 2, 0, -20) }, 35, 0), 2)
	T.eq(Targeting.shot(me, { at(2, 3, 0, -20) }, 35, 0), nil)
	T.eq(Targeting.shot(me, { at(2, 0, 0, 10) }, 35, 0), nil)
	T.eq(Targeting.shot(me, { at(1, 0, 0, -10) }, 35, 0), nil, "never self")
end)

T.test("shot picks the nearest along the ray, or the taunter", function()
	T.eq(Targeting.shot(me, { at(2, 0, 0, -20), at(3, 0, 0, -10) }, 35, 0), 3)
	T.eq(Targeting.shot(me, { at(2, 0, 0, -10), at(7, 0, 0, -20) }, 35, 0, 7), 7)
	T.eq(Targeting.shot(me, { at(2, 0, 0, -10), at(7, 0, 0, -40) }, 35, 0, 7), 2)
end)

T.test("shot turns clockwise by the angle", function()
	local r = math.rad(20)
	local right = at(2, math.sin(r) * 15, 0, -math.cos(r) * 15)
	T.eq(Targeting.shot(me, { right }, 35, 20), 2)
	T.eq(Targeting.shot(me, { right }, 35, 0), nil)
	T.eq(Targeting.shot(me, { right }, 35, -20), nil)
end)

T.test("shot enforces height and fails closed", function()
	T.eq(Targeting.shot(me, { at(2, 0, 7, -10) }, 35, 0), nil, "too high")
	T.eq(Targeting.shot(blind, { at(2, 0, 0, -10) }, 35, 0), nil, "zero look")
	local nan = 0 / 0
	T.eq(Targeting.shot(me, { at(2, nan, 0, -10) }, 35, 0), nil, "NaN position")
	T.eq(Targeting.shot(me, { at(2, 0, 0, -10) }, 35, nan), nil, "NaN angle")
end)

T.test("inRadius lists ids ascending, horizontally, with height cap", function()
	local origin = { x = 0, y = 0, z = 0 }
	T.eq(
		Targeting.inRadius(
			origin,
			{ at(4, -10, 0, 0), at(2, 5, 0, 0), at(3, 0, 0, 11), at(5, 0, 7, 1) },
			10
		),
		{ 2, 4 }
	)
	T.eq(Targeting.inRadius(origin, { at(1, 1, 0, 0), at(2, 2, 0, 0) }, 10, 1), { 2 })
	T.eq(Targeting.inRadius(origin, { at(2, 0 / 0, 0, 0) }, 10), {})
end)

T.test("dashHit finds the first fighter along the path", function()
	T.eq(Targeting.dashHit(me, { at(2, 1, 0, -6) }, 12), 2)
	T.eq(Targeting.dashHit(me, { at(2, 4, 0, -6) }, 12), nil)
	T.eq(Targeting.dashHit(me, { at(2, 0, 0, -14) }, 12), nil)
	T.eq(Targeting.dashHit(me, { at(2, 0, 0, -9), at(3, 1, 0, -4) }, 12), 3)
	T.eq(Targeting.dashHit(me, { at(2, 0, 0, 5) }, 12), nil, "behind")
	T.eq(Targeting.dashHit(me, { at(2, 0, 7, -5) }, 12), nil, "too high")
end)

T.test("zero look gives no shot or dash target", function()
	T.eq(Targeting.shot(blind, { at(2, 0, 0, -5) }, 35, 0), nil)
	T.eq(Targeting.dashHit(blind, { at(2, 0, 0, -5) }, 12), nil)
end)
