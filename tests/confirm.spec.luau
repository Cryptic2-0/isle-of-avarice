--!strict
local T = require("./harness")
local Confirm = require("../src/shared/Rules/Confirm")

T.test("the window is 3 seconds", function()
	T.eq(Confirm.WINDOW_SECONDS, 3)
end)

T.test("a first tap arms, a second tap on the same control goes ahead", function()
	local armed, go = Confirm.press(nil, "unclaim:R001", 10)
	T.eq(armed, { key = "unclaim:R001", at = 10 })
	T.eq(go, false)
	local after, go2 = Confirm.press(armed, "unclaim:R001", 12)
	T.eq(after, nil)
	T.eq(go2, true)
end)

T.test("the second tap counts up to exactly 3 seconds later", function()
	local armed = Confirm.press(nil, "k", 10)
	T.eq({ Confirm.press(armed, "k", 13) }, { nil, true })
	local late, go = Confirm.press(armed, "k", 13.01)
	T.eq(late, { key = "k", at = 13.01 })
	T.eq(go, false)
end)

T.test("a tap on another control arms that one instead", function()
	local armed = Confirm.press(nil, "unclaim:R001", 10)
	local other, go = Confirm.press(armed, "unclaim:R002", 11)
	T.eq(other, { key = "unclaim:R002", at = 11 })
	T.eq(go, false)
	T.eq(
		{ Confirm.press(other, "unclaim:R001", 11.5) },
		{ { key = "unclaim:R001", at = 11.5 }, false }
	)
end)

T.test("a clock that went backwards, or is not a number, only arms", function()
	local armed = Confirm.press(nil, "k", 10)
	T.eq({ Confirm.press(armed, "k", 9) }, { { key = "k", at = 9 }, false })
	local again, go = Confirm.press(armed, "k", 0 / 0)
	T.eq(go, false)
	T.eq(again and again.key, "k")
end)

T.test("isArmed", function()
	local armed = Confirm.press(nil, "k", 10)
	T.truthy(Confirm.isArmed(armed, "k", 10))
	T.truthy(Confirm.isArmed(armed, "k", 13))
	T.falsy(Confirm.isArmed(armed, "k", 13.5))
	T.falsy(Confirm.isArmed(armed, "other", 11))
	T.falsy(Confirm.isArmed(nil, "k", 11))
	T.falsy(Confirm.isArmed(armed, "k", 9))
end)

T.test("press does not change the record it is given", function()
	local armed = { key = "k", at = 10 }
	Confirm.press(armed, "k", 11)
	Confirm.press(armed, "j", 11)
	T.eq(armed, { key = "k", at = 10 })
end)
