--!strict
local T = require("./harness")
local BlindClaim = require("../src/shared/Rules/BlindClaim")
local ClaimView = require("../src/shared/Rules/ClaimView")

T.test("a fresh claim shows every slot open", function()
	local view = ClaimView.build("Ann", BlindClaim.start(100), 100)
	T.eq(view.title, "Claim on Ann")
	T.eq(view.picksText, "Picks left: 5")
	T.eq(view.secondsLeft, 30)
	T.eq(view.open, true)
	T.eq(#view.slots, 12)
	for _, slot in view.slots do
		T.eq(slot.state, "open")
	end
	T.eq(view.slots[7].label, "007")
	T.eq(view.slots[7].slot, 7)
	T.eq(view.slots[7].tier, "Silver")
	T.eq(view.slots[7].name, "Bottled Squall")
end)

T.test("picked slots show taken or miss", function()
	local victim: any = { claimed = {}, free = { "R007" } }
	local killer: any = { claimed = {}, free = {} }
	local c, v, k = BlindClaim.pick(BlindClaim.start(100), victim, {}, killer, 7, 101)
	c = BlindClaim.pick(c, v, {}, k, 3, 101)
	local view = ClaimView.build("Ann", c, 101)
	T.eq(view.slots[7].state, "taken")
	T.eq(view.slots[3].state, "miss")
	T.eq(view.slots[1].state, "open")
	T.eq(view.picksText, "Picks left: 3")
end)

T.test("seconds left is a ceiling", function()
	T.eq(ClaimView.build("Ann", BlindClaim.start(100), 100.2).secondsLeft, 30)
	T.eq(ClaimView.build("Ann", BlindClaim.start(100), 129.5).secondsLeft, 1)
end)

T.test("a reached tier limit locks that tier's slots", function()
	local claim = BlindClaim.start(100)
	claim.taken = { Platinum = 1 }
	local view = ClaimView.build("Ann", claim, 100)
	T.eq(view.slots[12].state, "locked")
	T.eq(view.slots[11].state, "open")
end)

T.test("a closed claim locks unpicked slots", function()
	local view = ClaimView.build("Ann", BlindClaim.start(100), 130)
	T.eq(view.open, false)
	T.eq(view.secondsLeft, 0)
	for _, slot in view.slots do
		T.eq(slot.state, "locked")
	end
	local late = ClaimView.build("Ann", BlindClaim.start(100), 500)
	T.eq(late.secondsLeft, 0)
end)
