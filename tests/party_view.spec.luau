--!strict
local T = require("./harness")
local PV = require("../src/shared/Rules/PartyView")

local sync: PV.Sync = {
	leader = 1,
	members = {
		{ userId = 1, name = "Ann" },
		{ userId = 2, name = "Bo" },
		{ userId = 3, name = "Cy" },
	},
}

T.test("title", function()
	T.eq(PV.title(nil), "")
	T.eq(PV.title(sync), "Party 3 / 4")
end)

T.test("rows: own row first, leader marked, health text", function()
	local rows = PV.rows(sync, 2, {
		["1"] = { health = 50, max = 100 },
		["2"] = { health = 100, max = 100 },
		["3"] = { health = 0, max = 100 },
	})
	T.eq(rows[1], {
		userId = 2,
		name = "Bo",
		isSelf = true,
		healthText = "100 / 100",
		share = 1,
		canRemove = false,
		canLead = false,
	})
	T.eq(rows[2], {
		userId = 1,
		name = "Ann (leader)",
		isSelf = false,
		healthText = "50 / 100",
		share = 0.5,
		canRemove = false,
		canLead = false,
	})
	T.eq(rows[3], {
		userId = 3,
		name = "Cy",
		isSelf = false,
		healthText = "defeated",
		share = 0,
		canRemove = false,
		canLead = false,
	})
	T.eq(#rows, 3)
end)

T.test("rows: the leader can remove and promote others", function()
	local rows = PV.rows(sync, 1, {})
	T.eq({ rows[1].name, rows[1].canRemove, rows[1].canLead }, { "Ann (leader)", false, false })
	T.eq({ rows[2].userId, rows[2].canRemove, rows[2].canLead }, { 2, true, true })
	T.eq({ rows[3].userId, rows[3].canRemove, rows[3].canLead }, { 3, true, true })
	T.eq({ rows[2].healthText, rows[2].share }, { "—", 0 })
end)

T.test("rows: odd health values", function()
	local function text(h: PV.Health): string
		return PV.rows(sync, 1, { ["2"] = h })[2].healthText
	end
	T.eq(text({ health = 74.2, max = 100 }), "75 / 100")
	T.eq(text({ health = 0.3, max = 100 }), "1 / 100")
	T.eq(text({ health = 0 / 0, max = 100 }), "—")
	T.eq(text({ health = math.huge, max = 100 }), "—")
	T.eq(text({ health = 50, max = 0 }), "—")
	T.eq(text({ health = 50, max = 0 / 0 }), "—")
	T.eq(text({ health = -5, max = 100 }), "defeated")
	local over = PV.rows(sync, 1, { ["2"] = { health = 150, max = 100 } })[2]
	T.eq({ over.healthText, over.share }, { "100 / 100", 1 })
	T.eq(PV.rows(nil, 1, {}), {})
end)

T.test("a viewer missing from the sync gets every row, none their own", function()
	local rows = PV.rows(sync, 9, {})
	T.eq({ #rows, rows[1].userId, rows[1].isSelf, rows[1].canRemove }, { 3, 1, false, false })
end)

T.test("ally ids and invite text", function()
	T.eq(PV.allyIds(sync, 2), { 1, 3 })
	T.eq(PV.allyIds(nil, 2), {})
	T.eq(PV.inviteText("Ann"), "Ann invites you to their party")
	local before = { leader = 1, members = { { userId = 1, name = "Ann" } } }
	PV.rows(before :: any, 1, {})
	PV.allyIds(before :: any, 1)
	T.eq(before, { leader = 1, members = { { userId = 1, name = "Ann" } } })
end)
