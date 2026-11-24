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

T.test("place adds the region first and hazards last", function()
	T.eq(
		StatusView.build(
			{ newShield = true, respawnShieldSeconds = 0, markedSeconds = 0 },
			false,
			{ name = "Thornwood", hazards = { "Briars" } }
		),
		{
			{ text = "Thornwood", kind = "region" },
			{ text = "New-player shield", kind = "shield" },
			{ text = "Briars", kind = "hazard" },
		}
	)
	T.eq(StatusView.build(nil, true, { name = "Tallyport", hazards = {} }), {
		{ text = "Tallyport", kind = "region" },
		{ text = "Safe zone", kind = "safe" },
	})
end)

T.test("Veil shows after Marked and before hazards, rounded up", function()
	T.eq(
		StatusView.build(
			{ newShield = false, respawnShieldSeconds = 0, markedSeconds = 60 },
			false,
			{ name = "Thornwood", hazards = { "Briars" } },
			125.2
		),
		{
			{ text = "Thornwood", kind = "region" },
			{ text = "MARKED 1:00", kind = "marked" },
			{ text = "Veiled 2:06", kind = "veil" },
			{ text = "Briars", kind = "hazard" },
		}
	)
end)

T.test("Veil needs no status, and hostile numbers add no line", function()
	T.eq(StatusView.build(nil, false, nil, 30), { { text = "Veiled 0:30", kind = "veil" } })
	for _, bad in { 0, -4, 0 / 0, math.huge } do
		T.eq(StatusView.build(nil, false, nil, bad), {})
	end
	T.eq(StatusView.build(nil, false, nil, nil), {})
end)

T.test("fit keeps the most urgent lines in their order and drops the region first", function()
	local lines: { StatusView.Line } = {
		{ text = "Tallyport", kind = "region" },
		{ text = "Safe zone", kind = "safe" },
		{ text = "New-player shield", kind = "shield" },
		{ text = "Respawn shield: 9s", kind = "shield" },
	}
	T.eq(StatusView.fit(lines, 4), lines)
	T.eq(StatusView.fit(lines, 3), { lines[2], lines[3], lines[4] })
	T.eq(StatusView.fit(lines, 2), { lines[3], lines[4] })
	T.eq(StatusView.fit(lines, 0), {})
	T.eq(#lines, 4)
	local urgent: { StatusView.Line } = {
		{ text = "Thornwood", kind = "region" },
		{ text = "MARKED 1:00", kind = "marked" },
		{ text = "Briars", kind = "hazard" },
	}
	T.eq(StatusView.fit(urgent, 2), { urgent[2], urgent[3] })
end)
