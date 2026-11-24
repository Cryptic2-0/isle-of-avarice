--!strict
-- Parties as plain state (spec 3.14): up to four players who cannot hurt each other and whose
-- support abilities reach each other. Session state only, nothing is saved. Pure: every
-- function builds new tables and the server owns the state.
local Types = require("../Types")

type Vec3 = Types.Vec3

export type Party = { leader: number, members: { number } }
export type State = { Party }
export type Helper = { position: Vec3, protected: boolean }
export type Helped = { id: number, position: Vec3, inFight: boolean, inDuel: boolean }

local Party = {}

Party.MAX_SIZE = 4
Party.INVITE_SECONDS = 20
Party.FIGHT_SECONDS = 30

function Party.new(): State
	return {}
end

-- The index of the party userId is in. Numbers are compared with ==, so NaN is never a member.
local function indexOf(state: State, userId: number): number?
	for i, party in state do
		for _, member in party.members do
			if member == userId then
				return i
			end
		end
	end
	return nil
end

local function copyParty(party: Party): Party
	return { leader = party.leader, members = table.clone(party.members) }
end

function Party.find(state: State, userId: number): Party?
	local i = indexOf(state, userId)
	if i == nil then
		return nil
	end
	return copyParty(state[i])
end

function Party.allies(state: State, userId: number): { number }
	local i = indexOf(state, userId)
	if i == nil then
		return {}
	end
	local out = {}
	for _, member in state[i].members do
		if member ~= userId then
			table.insert(out, member)
		end
	end
	return out
end

function Party.allied(state: State, a: number, b: number): boolean
	if a == b then
		return false
	end
	local i = indexOf(state, a)
	return i ~= nil and i == indexOf(state, b)
end

function Party.canInvite(state: State, inviterId: number, targetId: number): (boolean, string)
	if inviterId == targetId then
		return false, "BAD_REQUEST"
	end
	local i = indexOf(state, inviterId)
	if i ~= nil then
		local party = state[i]
		if party.leader ~= inviterId then
			return false, "PARTY_NOT_LEADER"
		end
		if #party.members >= Party.MAX_SIZE then
			return false, "PARTY_FULL"
		end
	end
	if indexOf(state, targetId) ~= nil then
		return false, "PARTY_TARGET_IN_PARTY"
	end
	return true, "PARTY_INVITE_SENT"
end

function Party.join(state: State, inviterId: number, targetId: number): (State?, string)
	local can, code = Party.canInvite(state, inviterId, targetId)
	if not can then
		return nil, code
	end
	local out = table.clone(state)
	local i = indexOf(state, inviterId)
	if i == nil then
		table.insert(out, { leader = inviterId, members = { inviterId, targetId } })
	else
		local party = copyParty(state[i])
		table.insert(party.members, targetId)
		out[i] = party
	end
	return out, "PARTY_JOINED"
end

-- Takes userId out of the party at index i. A party left with one member is removed, and a
-- leader who left is replaced by the first remaining member.
local function removeMember(state: State, i: number, userId: number): State
	local out = table.clone(state)
	local party = copyParty(state[i])
	local at = table.find(party.members, userId)
	if at ~= nil then
		table.remove(party.members, at)
	end
	if #party.members <= 1 then
		table.remove(out, i)
		return out
	end
	if party.leader == userId then
		party.leader = party.members[1]
	end
	out[i] = party
	return out
end

function Party.leave(state: State, userId: number): (State?, string)
	local i = indexOf(state, userId)
	if i == nil then
		return nil, "PARTY_NOT_IN"
	end
	return removeMember(state, i, userId), "PARTY_LEFT"
end

-- The shared checks of kick and promote: the leader's party index and the target id, or a code.
local function leaderTarget(
	state: State,
	leaderId: number,
	rawTargetId: any
): (number?, number?, string?)
	local i = indexOf(state, leaderId)
	if i == nil then
		return nil, nil, "PARTY_NOT_IN"
	end
	local party = state[i]
	if party.leader ~= leaderId then
		return nil, nil, "PARTY_NOT_LEADER"
	end
	if type(rawTargetId) ~= "number" or rawTargetId == leaderId then
		return nil, nil, "BAD_REQUEST"
	end
	if table.find(party.members, rawTargetId) == nil then
		return nil, nil, "BAD_REQUEST"
	end
	return i, rawTargetId, nil
end

function Party.kick(state: State, leaderId: number, rawTargetId: any): (State?, string)
	local i, targetId, code = leaderTarget(state, leaderId, rawTargetId)
	if i == nil or targetId == nil then
		return nil, code :: string
	end
	return removeMember(state, i, targetId), "PARTY_MEMBER_KICKED"
end

function Party.promote(state: State, leaderId: number, rawTargetId: any): (State?, string)
	local i, targetId, code = leaderTarget(state, leaderId, rawTargetId)
	if i == nil or targetId == nil then
		return nil, code :: string
	end
	local out = table.clone(state)
	local party = copyParty(state[i])
	party.leader = targetId
	out[i] = party
	return out, "PARTY_NEW_LEADER"
end

function Party.reach(helper: Helper, allies: { Helped }, radius: number): ({ number }, boolean)
	local ids = {}
	local anyFight = false
	for _, ally in allies do
		local dx = ally.position.x - helper.position.x
		local dy = ally.position.y - helper.position.y
		local dz = ally.position.z - helper.position.z
		-- Written as <= so a NaN position or radius makes the test false and reaches nobody.
		local near = math.sqrt(dx * dx + dy * dy + dz * dz) <= radius
		if near and not ally.inDuel and not (helper.protected and ally.inFight) then
			table.insert(ids, ally.id)
			if ally.inFight then
				anyFight = true
			end
		end
	end
	return ids, anyFight
end

function Party.inFight(marked: boolean, lastFightAt: number?, now: number): boolean
	if marked then
		return true
	end
	-- Written with not (>=) so a NaN time counts as still fighting.
	return lastFightAt ~= nil and not (now - lastFightAt >= Party.FIGHT_SECONDS)
end

return Party
