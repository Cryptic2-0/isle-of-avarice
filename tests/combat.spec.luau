--!strict
local T = require("./harness")
local Combat = require("../src/shared/Rules/Combat")

local me = { id = 1, position = { x = 0, y = 0, z = 0 }, look = { x = 0, y = 0, z = -1 } }

local function at(id: number, x: number, y: number, z: number): Combat.Fighter
	return { id = id, position = { x = x, y = y, z = z }, look = { x = 0, y = 0, z = 1 } }
end

T.test("pickTarget finds a fighter in front", function()
	T.eq(Combat.pickTarget(me, { at(2, 0, 0, -5) }), 2)
end)

T.test("pickTarget rejects behind and outside the arc", function()
	T.eq(Combat.pickTarget(me, { at(2, 0, 0, 5) }), nil, "behind")
	T.eq(Combat.pickTarget(me, { at(2, 5, 0, -5) }), 2, "45 degrees off, distance 7.07")
	T.eq(Combat.pickTarget(me, { at(2, 7, 0, -2) }), nil, "outside the arc")
end)

T.test("pickTarget enforces reach and height", function()
	T.eq(Combat.pickTarget(me, { at(2, 0, 0, -8.1) }), nil, "out of reach")
	T.eq(Combat.pickTarget(me, { at(2, 0, 0, -8) }), 2, "exactly at reach")
	T.eq(Combat.pickTarget(me, { at(2, 0, 7, -3) }), nil, "too high")
end)

T.test("pickTarget picks the nearest and never the attacker", function()
	T.eq(Combat.pickTarget(me, { at(2, 5, 0, -5), at(3, 0, 0, -5) }), 3)
	T.eq(Combat.pickTarget(me, { at(1, 0, 0, -2) }), nil, "never yourself")
end)

T.test("pickTarget edge cases", function()
	local blind = { id = 1, position = me.position, look = { x = 0, y = 0, z = 0 } }
	T.eq(Combat.pickTarget(blind, { at(2, 0, 0, -5) }), nil, "zero look")
	T.eq(Combat.pickTarget(me, { at(2, 0, 0, 0) }), 2, "same position is in the arc")
end)

T.test("pickTarget ignores the y axis of look", function()
	local tilted = { id = 1, position = me.position, look = { x = 0, y = 5, z = -1 } }
	T.eq(Combat.pickTarget(tilted, { at(2, 0, 0, -5) }), 2, "tilted look still hits ahead")
	local vertical = { id = 1, position = me.position, look = { x = 0, y = 1, z = 0 } }
	T.eq(Combat.pickTarget(vertical, { at(2, 0, 0, -5) }), nil, "purely vertical look")
end)

T.test("pickTarget fails closed on NaN and infinite input", function()
	local nan = 0 / 0
	local ahead = { at(2, 0, 0, -5) }
	local nanLook = { id = 1, position = me.position, look = { x = nan, y = 0, z = -1 } }
	T.eq(Combat.pickTarget(nanLook, ahead), nil, "NaN look")
	local infLook = { id = 1, position = me.position, look = { x = 0, y = 0, z = math.huge } }
	T.eq(Combat.pickTarget(infLook, { at(2, 0, 0, 5) }), nil, "infinite look")
	local nanPos = { id = 1, position = { x = nan, y = 0, z = 0 }, look = me.look }
	T.eq(Combat.pickTarget(nanPos, ahead), nil, "NaN attacker position")
	T.eq(Combat.pickTarget(me, { at(2, nan, 0, -5) }), nil, "NaN candidate position")
	T.eq(Combat.pickTarget(me, { at(2, 0, nan, -5) }), nil, "NaN candidate height")
end)

T.test("canStrike honours the cooldown", function()
	T.truthy(Combat.canStrike(nil, 10))
	T.falsy(Combat.canStrike(10, 10.79))
	T.truthy(Combat.canStrike(10, 10.8))
end)

T.test("hit log credits the latest attacker inside the window", function()
	local log = Combat.recordHit({}, 2, 1, 100)
	T.eq(Combat.creditFor(log, 2, 115, 15), 1)
	T.eq(Combat.creditFor(log, 2, 115.1, 15), nil)
	T.eq(Combat.creditFor(log, 2, 130, 30), 1)
	T.eq(Combat.creditFor(log, 3, 100, 15), nil)
	T.eq(Combat.creditFor(Combat.recordHit(log, 2, 5, 110), 2, 112, 15), 5, "latest attacker")
	T.eq(Combat.clear(log, 2), {})
	T.eq(Combat.creditFor(log, 2, 101, 15), 1, "clear did not mutate")
end)

T.test("pickTarget honours a custom range", function()
	T.eq(Combat.pickTarget(me, { at(2, 0, 0, -5) }, 4), nil)
	T.eq(Combat.pickTarget(me, { at(2, 0, 0, -5) }, 5), 2)
end)

T.test("pickTarget prefers a taunter that is in reach", function()
	T.eq(
		Combat.pickTarget(me, { at(2, 0, 0, -3), at(7, 0, 0, -6) }, nil, 7),
		7,
		"taunter in reach wins"
	)
	T.eq(
		Combat.pickTarget(me, { at(2, 0, 0, -3), at(7, 0, 0, -9) }, nil, 7),
		2,
		"taunter out of reach"
	)
	T.eq(Combat.pickTarget(me, { at(2, 0, 0, -3), at(7, 0, 0, 6) }, nil, 7), 2, "taunter behind")
	T.eq(Combat.pickTarget(me, { at(2, 0, 0, -3), at(7, 0, 9, -6) }, nil, 7), 2, "taunter too high")
	T.eq(Combat.pickTarget(me, { at(1, 0, 0, -3), at(2, 0, 0, -6) }, nil, 1), 2, "taunter is self")
end)
