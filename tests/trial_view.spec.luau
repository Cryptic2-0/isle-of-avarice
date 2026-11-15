--!strict
local T = require("./harness")
local TrialRun = require("../src/shared/Rules/TrialRun")
local TrialView = require("../src/shared/Rules/TrialView")

local fresh = TrialRun.newRecord()

T.test("offer: what the Warden's window shows", function()
	T.eq(TrialView.offer("tidewalk", fresh, nil, 5000, 0, 20), {
		trialId = "tidewalk",
		title = "Tidewalk",
		warden = "Harbour Warden",
		goal = "Touch 6 markers in order.",
		timeText = "Time: 60 seconds",
		rewardText = "Reward: 30 Coin, 120 XP",
		relicText = "Relic: Low-Tide Tally Stick (Silver)",
		sealed = false,
		canStart = true,
		note = "",
	})
end)

T.test("offer: a sealed Relic is said so, and the trial can still be run for Coin", function()
	local s = TrialView.offer("tidewalk", fresh, nil, 5000, 8, 20)
	T.eq(
		{ s.sealed, s.relicText, s.canStart, s.note },
		{ true, "Relic: Low-Tide Tally Stick (Silver) — sealed on this server", true, "" } :: { any }
	)
	T.eq(TrialView.offer("tallymans_duel", fresh, nil, 5000, 4, 20).sealed, true, "Gold cap 4")
	T.eq(TrialView.offer("tallymans_duel", fresh, nil, 5000, 3, 20).sealed, false)
	-- Sealed and no room: there is no Relic to lose, so no warning.
	T.eq(TrialView.offer("tidewalk", fresh, nil, 5000, 8, 0).note, "")
end)

T.test("offer: notes for full slots, a cooldown and a running trial", function()
	local full = TrialView.offer("tidewalk", fresh, nil, 5000, 0, 0)
	T.eq(
		{ full.canStart, full.note },
		{ true, "Your free slots are full, so the Relic would be lost." } :: { any }
	)
	local passed = TrialRun.finish(fresh, "tidewalk", true, 5000)
	local cd = TrialView.offer("tidewalk", passed, nil, 5025, 0, 0)
	T.eq({ cd.canStart, cd.note }, { false, "Try again in 4:35." } :: { any })
	T.eq(TrialView.offer("tidewalk", passed, nil, 5000, 0, 20).note, "Try again in 5:00.")
	T.eq(TrialView.offer("tidewalk", passed, nil, 5299.5, 0, 20).note, "Try again in 0:01.")
	local busy = TrialView.offer("tidewalk", passed, "salt_post", 5000, 0, 20)
	T.eq({ busy.canStart, busy.note }, { false, "Finish your current trial first." } :: { any })
end)

T.test("offer: an unknown trial shows an empty window that cannot start", function()
	local none = TrialView.offer("nope", fresh, nil, 5000, 0, 20)
	T.eq({ none.trialId, none.title, none.canStart }, { "nope", "", false } :: { any })
end)

T.test("hud: the running trial, its clock and the quest line", function()
	T.eq(TrialView.hud(nil, 0), { "The Unpaid Debt: 0 / 4, next: Tidewalk" })
	T.eq(
		TrialView.hud({ trialId = "tidewalk", progress = 2, goal = 6, secondsLeft = 42.2 }, 1),
		{ "Tidewalk: marker 2 / 6", "Time left 0:43", "The Unpaid Debt: 1 / 4, next: Salt Post" }
	)
	T.eq(
		TrialView.hud({ trialId = "cull_the_pack", progress = 3, goal = 5, secondsLeft = 61 }, 3),
		{
			"Cull the Pack: defeated 3 / 5",
			"Time left 1:01",
			"The Unpaid Debt: 3 / 4, next: defeat the Brine Colossus",
		}
	)
	local salt =
		TrialView.hud({ trialId = "salt_post", progress = 0, goal = 1, secondsLeft = -3 }, 2)
	T.eq(salt, {
		"Salt Post: carry the parcel to the Harbour Warden",
		"Time left 0:00",
		"The Unpaid Debt: 2 / 4, next: The Tallyman's Duel",
	})
	local duel = TrialView.hud(
		{ trialId = "tallymans_duel", progress = 0, goal = 1, secondsLeft = 0 / 0 },
		2
	)
	T.eq(
		{ duel[1], duel[2] },
		{ "The Tallyman's Duel: defeat the Drowned Tallyman", "Time left 0:00" }
	)
end)

T.test("hud: a bad quest step or trial id still gives sensible lines", function()
	for _, bad in { -1, 4, 1.5, 0 / 0 } do
		T.eq(TrialView.hud(nil, bad), { "The Unpaid Debt: 0 / 4, next: Tidewalk" })
	end
	T.eq(
		TrialView.hud({ trialId = "nope", progress = 0, goal = 1, secondsLeft = 5 }, 0),
		{ "The Unpaid Debt: 0 / 4, next: Tidewalk" }
	)
end)
