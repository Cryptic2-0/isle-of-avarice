--!strict
local T = require("./harness")
local StatusView = require("../src/shared/Rules/StatusView")

T.test("no status: only the safe-zone line, and only inside", function()
	T.eq(StatusView.build(nil, false), {})
	T.eq(StatusView.build(nil, true), { { text = "Safe zone", kind = "safe" } })
end)

T.test("lines come in order: safe, new shield, respawn shield", function()
	T.eq(
		StatusView.build({ newShield = true, respawnShieldSeconds = 41.2, markedSeconds = 0 }, true),
		{
			{ text = "Safe zone", kind = "safe" },
			{ text = "New-player shield", kind = "shield" },
			{ text = "Respawn shield: 42s", kind = "shield" },
		}
	)
end)

T.test("Marked shows minutes and two-digit seconds", function()
	T.eq(
		StatusView.build(
			{ newShield = false, respawnShieldSeconds = 0, markedSeconds = 271 },
			false
		),
		{ { text = "MARKED 4:31", kind = "marked" } }
	)
	T.eq(
		StatusView.build({ newShield = false, respawnShieldSeconds = 0, markedSeconds = 60 }, false)[1].text,
		"MARKED 1:00"
	)
	T.eq(
		StatusView.build(
			{ newShield = false, respawnShieldSeconds = 0, markedSeconds = 0.2 },
			false
		)[1].text,
		"MARKED 0:01"
	)
end)

T.test("hostile numbers never raise and show nothing", function()
	T.eq(
		StatusView.build(
			{ newShield = false, respawnShieldSeconds = 0 / 0, markedSeconds = -5 },
			false
		),
		{}
	)
end)
