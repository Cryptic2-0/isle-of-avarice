--!strict
local T = require("./harness")
local Party = require("../src/shared/Rules/Party")

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

-- A step that must succeed: checks its code and returns the new state.
local function ok(expected: string, state: Party.State?, code: string): Party.State
	T.eq(code, expected)
	T.truthy(state ~= nil, expected)
	return state :: Party.State
end

-- Members 1..n in one party led by 1.
local function partyOf(n: number): Party.State
	local s = Party.new()
	for id = 2, n do
		s = ok("PARTY_JOINED", Party.join(s, 1, id))
	end
	return s
end

local function helped(id: number, x: number, over: { [string]: any }?): Party.Helped
	local h: { [string]: any } =
		{ id = id, position = { x = x, y = 0, z = 0 }, inFight = false, inDuel = false }
	for k, v in over or {} do
		h[k] = v
	end
	return h :: any
end

T.test("party constants", function()
	T.eq({ Party.MAX_SIZE, Party.INVITE_SECONDS, Party.FIGHT_SECONDS }, { 4, 20, 30 })
end)

T.test("a first invite makes a party of two led by the inviter", function()
	T.eq(Party.new(), {})
	T.eq({ Party.canInvite({}, 1, 2) }, { true, "PARTY_INVITE_SENT" })
	local s = ok("PARTY_JOINED", Party.join({}, 1, 2))
	T.eq(s, { { leader = 1, members = { 1, 2 } } })
	T.eq(Party.find(s, 2), { leader = 1, members = { 1, 2 } })
	T.eq(Party.find(s, 3), nil)
	T.eq({ Party.allies(s, 1), Party.allies(s, 2), Party.allies(s, 3) }, { { 2 }, { 1 }, {} })
	T.eq({
		Party.allied(s, 1, 2),
		Party.allied(s, 2, 1),
		Party.allied(s, 1, 1),
		Party.allied(s, 1, 3),
	}, { true, true, false, false })
end)

T.test("a party grows to four and no further", function()
	local s = partyOf(4)
	T.eq(s, { { leader = 1, members = { 1, 2, 3, 4 } } })
	T.eq(Party.allies(s, 3), { 1, 2, 4 })
	T.eq({ Party.canInvite(s, 1, 5) }, { false, "PARTY_FULL" })
	T.eq({ Party.join(s, 1, 5) }, { nil, "PARTY_FULL" })
end)

T.test("invite refusals, in order", function()
	local s = partyOf(2)
	T.eq({ Party.canInvite(s, 1, 1) }, { false, "BAD_REQUEST" })
	T.eq({ Party.canInvite({}, 7, 7) }, { false, "BAD_REQUEST" })
	T.eq({ Party.canInvite(s, 2, 3) }, { false, "PARTY_NOT_LEADER" })
	T.eq({ Party.join(s, 2, 3) }, { nil, "PARTY_NOT_LEADER" })
	T.eq({ Party.canInvite(s, 1, 2) }, { false, "PARTY_TARGET_IN_PARTY" })
	T.eq({ Party.canInvite(s, 3, 1) }, { false, "PARTY_TARGET_IN_PARTY" })
	T.eq({ Party.canInvite(partyOf(4), 2, 9) }, { false, "PARTY_NOT_LEADER" }) -- leadership before size
	local two = ok("PARTY_JOINED", Party.join(s, 5, 6))
	T.eq(two, { { leader = 1, members = { 1, 2 } }, { leader = 5, members = { 5, 6 } } })
	T.falsy(Party.allied(two, 2, 5))
	T.eq({ Party.join(two, 1, 6) }, { nil, "PARTY_TARGET_IN_PARTY" })
end)

T.test("leaving: the earliest member leads, a party of one breaks up", function()
	local s = partyOf(4)
	local a = ok("PARTY_LEFT", Party.leave(s, 3))
	T.eq(a, { { leader = 1, members = { 1, 2, 4 } } })
	local b = ok("PARTY_LEFT", Party.leave(a, 1))
	T.eq(b, { { leader = 2, members = { 2, 4 } } })
	local c = ok("PARTY_LEFT", Party.leave(b, 4))
	T.eq(c, {})
	T.eq(Party.find(c, 2), nil)
	T.eq({ Party.leave(c, 2) }, { nil, "PARTY_NOT_IN" })
	T.eq({ Party.leave({}, 9) }, { nil, "PARTY_NOT_IN" })
	-- other parties are untouched
	local two = ok("PARTY_JOINED", Party.join(partyOf(2), 5, 6))
	T.eq(ok("PARTY_LEFT", Party.leave(two, 2)), { { leader = 5, members = { 5, 6 } } })
end)

T.test("removing a member: leader only, a member only", function()
	local s = partyOf(3)
	T.eq({ Party.kick({}, 1, 2) }, { nil, "PARTY_NOT_IN" })
	T.eq({ Party.kick(s, 2, 3) }, { nil, "PARTY_NOT_LEADER" })
	for _, bad in { 1, 9, "3", 0 / 0, 2.5, {} } :: { any } do
		T.eq({ Party.kick(s, 1, bad) }, { nil, "BAD_REQUEST" }, tostring(bad))
	end
	T.eq({ Party.kick(s, 1, nil) }, { nil, "BAD_REQUEST" })
	local k = ok("PARTY_MEMBER_KICKED", Party.kick(s, 1, 3))
	T.eq(k, { { leader = 1, members = { 1, 2 } } })
	T.eq(ok("PARTY_MEMBER_KICKED", Party.kick(k, 1, 2)), {})
end)

T.test("handing over the lead", function()
	local s = partyOf(3)
	T.eq({ Party.promote({}, 1, 2) }, { nil, "PARTY_NOT_IN" })
	T.eq({ Party.promote(s, 3, 2) }, { nil, "PARTY_NOT_LEADER" })
	for _, bad in { 1, 9, "2", 0 / 0 } :: { any } do
		T.eq({ Party.promote(s, 1, bad) }, { nil, "BAD_REQUEST" }, tostring(bad))
	end
	local p = ok("PARTY_NEW_LEADER", Party.promote(s, 1, 3))
	T.eq(p, { { leader = 3, members = { 1, 2, 3 } } })
	T.eq({ Party.canInvite(p, 1, 4) }, { false, "PARTY_NOT_LEADER" })
	T.eq({ Party.canInvite(p, 3, 4) }, { true, "PARTY_INVITE_SENT" })
	T.eq(ok("PARTY_LEFT", Party.leave(p, 3)), { { leader = 1, members = { 1, 2 } } })
end)

T.test("no party function mutates its arguments", function()
	local s = partyOf(3)
	local before = copy(s)
	Party.join(s, 1, 4)
	Party.leave(s, 2)
	Party.leave(s, 1)
	Party.kick(s, 1, 3)
	Party.promote(s, 1, 2)
	Party.canInvite(s, 1, 5)
	T.eq(s, before)
	local found = Party.find(s, 1) :: Party.Party
	table.insert(found.members, 99)
	found.leader = 99
	table.insert(Party.allies(s, 1), 98)
	T.eq(s, before)
end)

T.test("support reach", function()
	local me: Party.Helper = { position = { x = 0, y = 0, z = 0 }, protected = false }
	T.eq(
		{ Party.reach(me, { helped(2, 10), helped(3, 15), helped(4, 15.1) }, 15) },
		{ { 2, 3 }, false }
	)
	T.eq(
		{ Party.reach(me, { helped(2, 0, { position = { x = 0, y = 15.5, z = 0 } }) }, 15) },
		{ {}, false }
	)
	T.eq({ Party.reach(me, { helped(2, 5, { inDuel = true }) }, 15) }, { {}, false })
	T.eq(
		{ Party.reach(me, { helped(2, 5, { inFight = true }), helped(3, 6) }, 15) },
		{ { 2, 3 }, true }
	)
	local safe: Party.Helper = { position = { x = 0, y = 0, z = 0 }, protected = true }
	T.eq(
		{ Party.reach(safe, { helped(2, 5, { inFight = true }), helped(3, 6) }, 15) },
		{ { 3 }, false }
	)
	T.eq({ Party.reach(me, { helped(2, 0 / 0) }, 15) }, { {}, false })
	T.eq({ Party.reach(me, { helped(2, 5) }, 0 / 0) }, { {}, false })
	T.eq({ Party.reach(me, { helped(2, 5) }, -1) }, { {}, false })
	local lost: Party.Helper = { position = { x = 0 / 0, y = 0, z = 0 }, protected = false }
	T.eq({ Party.reach(lost, { helped(2, 5) }, 15) }, { {}, false })
	T.eq({ Party.reach(me, {}, 15) }, { {}, false })
	local list = { helped(2, 5, { inFight = true }) }
	local listBefore = copy(list)
	Party.reach(safe, list, 15)
	T.eq(list, listBefore)
	T.eq(safe, { position = { x = 0, y = 0, z = 0 }, protected = true })
end)

T.test("in a player fight", function()
	T.eq({
		Party.inFight(true, nil, 100),
		Party.inFight(false, nil, 100),
		Party.inFight(false, 71, 100),
		Party.inFight(false, 70, 100),
		Party.inFight(false, 0 / 0, 100),
		Party.inFight(false, 80, 0 / 0),
	}, { true, false, true, false, true, true })
end)
