--!strict
local T = require("./harness")
local TrialRun = require("../src/shared/Rules/TrialRun")

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

local rec = TrialRun.newRecord()
local function started(id: string): TrialRun.Run
	local run = TrialRun.start(rec, nil, id, 100, 5000)
	return run :: TrialRun.Run
end

T.test("constants and a new record", function()
	T.eq({
		TrialRun.PASS_COOLDOWN,
		TrialRun.FAIL_COOLDOWN,
		TrialRun.MARKER_RADIUS,
		TrialRun.DELIVERY_RADIUS,
		TrialRun.WARDEN_REACH,
	}, { 300, 30, 6, 10, 15 })
	T.eq(rec, { cooldowns = {}, questStep = 0 })
end)

T.test("start: one trial at a time, only known ids", function()
	local run, code = TrialRun.start(rec, nil, "tidewalk", 100, 5000)
	T.eq(
		{ run, code },
		{ { trialId = "tidewalk", endsAt = 160, progress = 0, goal = 6 }, "TRIAL_STARTED" } :: { any }
	)
	T.eq({ TrialRun.start(rec, run, "salt_post", 100, 5000) }, { nil, "TRIAL_BUSY" } :: { any })
	for _, bad in { "nope", "", 5, {}, true } :: { any } do
		T.eq({ TrialRun.start(rec, nil, bad, 100, 5000) }, { nil, "BAD_REQUEST" } :: { any })
	end
	T.eq({ TrialRun.start(rec, nil, nil, 100, 5000) }, { nil, "BAD_REQUEST" } :: { any })
	-- A bad id is refused before the busy check.
	T.eq({ TrialRun.start(rec, run, "nope", 100, 5000) }, { nil, "BAD_REQUEST" } :: { any })
	T.eq({
		TrialRun.goal("tidewalk"),
		TrialRun.goal("gullstep_climb"),
		TrialRun.goal("cull_the_pack"),
		TrialRun.goal("shellbreaker"),
		TrialRun.goal("salt_post"),
		TrialRun.goal("tallymans_duel"),
		TrialRun.goal("nope"),
	}, { 6, 8, 5, 3, 1, 1, 0 })
end)

T.test("cooldowns: 300 s after a pass, 30 s after a fail, per trial", function()
	local passed = TrialRun.finish(rec, "tidewalk", true, 5000)
	T.eq(passed.cooldowns.tidewalk, 5300)
	T.eq(select(2, TrialRun.start(passed, nil, "tidewalk", 0, 5299)), "TRIAL_COOLDOWN")
	T.eq(select(2, TrialRun.start(passed, nil, "tidewalk", 0, 5300)), "TRIAL_STARTED")
	T.eq(select(2, TrialRun.start(passed, nil, "salt_post", 0, 5000)), "TRIAL_STARTED")
	local failed = TrialRun.finish(rec, "tidewalk", false, 5000)
	T.eq({
		TrialRun.cooldownLeft(failed, "tidewalk", 5000),
		TrialRun.cooldownLeft(failed, "tidewalk", 5030),
	}, { 30, 0 })
	T.eq(TrialRun.cooldownLeft(rec, "tidewalk", 5000), 0)
	-- No trial is ever locked for more than 300 seconds, whatever was saved.
	local huge = { cooldowns = { tidewalk = 1e12 }, questStep = 0 }
	T.eq(TrialRun.cooldownLeft(huge, "tidewalk", 5000), 300)
	T.eq(TrialRun.cooldownLeft(passed, "tidewalk", 0 / 0), 300)
	T.eq(
		TrialRun.cooldownLeft({ cooldowns = { tidewalk = 0 / 0 }, questStep = 0 }, "tidewalk", 5000),
		300
	)
	T.eq(select(2, TrialRun.start(passed, nil, "tidewalk", 0, 0 / 0)), "TRIAL_COOLDOWN")
end)

T.test("progress: markers in order, the right quarry, delivery and duel in one step", function()
	local run = started("tidewalk")
	local r1 = TrialRun.reachMarker(run, 1)
	T.eq(
		{ r1.progress, TrialRun.reachMarker(run, 2).progress, TrialRun.reachMarker(r1, 1).progress },
		{ 1, 0, 1 }
	)
	local done = run
	for i = 1, 6 do
		done = TrialRun.reachMarker(done, i)
	end
	T.truthy(TrialRun.isPassed(done))
	T.falsy(TrialRun.isPassed(r1))
	T.eq(TrialRun.reachMarker(done, 7).progress, 6)

	local hunt = started("cull_the_pack")
	T.eq({
		TrialRun.countDefeat(hunt, "shellback").progress,
		TrialRun.countDefeat(hunt, "brinehound").progress,
	}, { 0, 1 })
	local h = hunt
	for _ = 1, 6 do
		h = TrialRun.countDefeat(h, "brinehound")
	end
	T.eq(h.progress, 5)
	T.truthy(TrialRun.isPassed(h))

	T.eq(TrialRun.complete(started("salt_post")).progress, 1)
	T.eq(TrialRun.complete(started("tallymans_duel")).progress, 1)
	T.eq(TrialRun.complete(run).progress, 0)
	T.eq(TrialRun.complete(hunt).progress, 0)
	T.eq(TrialRun.countDefeat(run, "brinehound").progress, 0)
	T.eq(TrialRun.reachMarker(hunt, 1).progress, 0)
	T.eq({
		TrialRun.isExpired(run, 159.9),
		TrialRun.isExpired(run, 160),
		TrialRun.isExpired(run, 0 / 0),
	}, { false, true, true })
end)

T.test("the quest counts only the next step, then starts again", function()
	T.eq({ TrialRun.advanceQuest(0, "tidewalk") }, { 1, false } :: { any })
	T.eq({ TrialRun.advanceQuest(0, "salt_post") }, { 0, false } :: { any })
	T.eq({ TrialRun.advanceQuest(1, "salt_post") }, { 2, false } :: { any })
	T.eq({ TrialRun.advanceQuest(2, "tidewalk") }, { 2, false } :: { any })
	T.eq({ TrialRun.advanceQuest(2, "colossus") }, { 2, false } :: { any })
	T.eq({ TrialRun.advanceQuest(2, "tallymans_duel") }, { 3, false } :: { any })
	T.eq({ TrialRun.advanceQuest(3, "colossus") }, { 0, true } :: { any })
	T.eq({ TrialRun.advanceQuest(3, "gullstep_climb") }, { 3, false } :: { any })
	for _, bad in { -1, 4, 1.5, 0 / 0 } do
		T.eq({ TrialRun.advanceQuest(bad, "tidewalk") }, { 0, false } :: { any })
	end
end)

T.test("sanitize turns any saved value into a valid record", function()
	T.eq(TrialRun.sanitize(nil, 5000), TrialRun.newRecord())
	T.eq(TrialRun.sanitize("junk", 5000), TrialRun.newRecord())
	T.eq(TrialRun.sanitize({ cooldowns = "x", questStep = {} }, 5000), TrialRun.newRecord())
	T.eq(
		TrialRun.sanitize({
			cooldowns = {
				tidewalk = 1e12,
				salt_post = 4000,
				gullstep_climb = 5100,
				nope = 9999,
				shellbreaker = 0 / 0,
				cull_the_pack = "x",
				tallymans_duel = math.huge,
			},
			questStep = 2,
		}, 5000),
		{ cooldowns = { tidewalk = 5300, gullstep_climb = 5100 }, questStep = 2 }
	)
	for _, bad in { -1, 4, 1.5, 0 / 0, "2", {} } :: { any } do
		T.eq(TrialRun.sanitize({ questStep = bad }, 0).questStep, 0)
	end
	for step = 0, 3 do
		T.eq(TrialRun.sanitize({ questStep = step }, 0).questStep, step)
	end
	-- A clock that is not a number keeps nothing.
	T.eq(TrialRun.sanitize({ cooldowns = { tidewalk = 5100 } }, 0 / 0).cooldowns, {})
end)

T.test("no function changes its arguments", function()
	local record = TrialRun.finish(rec, "salt_post", true, 5000)
	local record0 = copy(record)
	local run = started("tidewalk")
	local hunt = started("cull_the_pack")
	local delivery = started("salt_post")
	local run0, hunt0, delivery0 = copy(run), copy(hunt), copy(delivery)
	TrialRun.start(record, nil, "tidewalk", 100, 5000)
	TrialRun.finish(record, "tidewalk", false, 6000)
	TrialRun.reachMarker(run, 1)
	TrialRun.countDefeat(hunt, "brinehound")
	TrialRun.complete(delivery)
	T.eq({ record, run, hunt, delivery }, { record0, run0, hunt0, delivery0 } :: { any })
	local raw = { cooldowns = { tidewalk = 1e12, nope = 1 }, questStep = 9 }
	local raw0 = copy(raw)
	TrialRun.sanitize(raw, 5000)
	T.eq(raw, raw0)
	T.eq(rec, { cooldowns = {}, questStep = 0 })
end)
