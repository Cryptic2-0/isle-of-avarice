--!strict
-- What the party panel shows (spec 3.15), from the server's PartySync and the health the client
-- already knows. Pure: the client draws it, and a missing or odd number never breaks a row.
local Party = require("./Party")

export type Member = { userId: number, name: string }
-- Members in join order.
export type Sync = { leader: number, members: { Member } }
export type Health = { health: number, max: number }
export type Row = {
	userId: number,
	name: string,
	isSelf: boolean,
	healthText: string,
	share: number,
	canRemove: boolean,
	canLead: boolean,
}

local PartyView = {}

local UNKNOWN = "—"

local function isFinite(n: any): boolean
	return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

local function healthOf(h: Health?): (string, number)
	if h == nil or not isFinite(h.health) or not isFinite(h.max) or h.max <= 0 then
		return UNKNOWN, 0
	end
	if h.health <= 0 then
		return "defeated", 0
	end
	local text = string.format("%d / %d", math.ceil(math.min(h.health, h.max)), math.floor(h.max))
	return text, math.clamp(h.health / h.max, 0, 1)
end

local function rowFor(
	member: Member,
	sync: Sync,
	selfId: number,
	healths: { [string]: Health }
): Row
	local text, share = healthOf(healths[tostring(member.userId)])
	local isSelf = member.userId == selfId
	local leads = sync.leader == selfId and not isSelf
	return {
		userId = member.userId,
		name = if member.userId == sync.leader then member.name .. " (leader)" else member.name,
		isSelf = isSelf,
		healthText = text,
		share = share,
		canRemove = leads,
		canLead = leads,
	}
end

function PartyView.title(sync: Sync?): string
	if sync == nil then
		return ""
	end
	return string.format("Party %d / %d", #sync.members, Party.MAX_SIZE)
end

function PartyView.rows(sync: Sync?, selfId: number, healths: { [string]: Health }): { Row }
	local rows: { Row } = {}
	if sync == nil then
		return rows
	end
	for _, member in sync.members do
		if member.userId == selfId then
			table.insert(rows, rowFor(member, sync, selfId, healths))
		end
	end
	for _, member in sync.members do
		if member.userId ~= selfId then
			table.insert(rows, rowFor(member, sync, selfId, healths))
		end
	end
	return rows
end

function PartyView.allyIds(sync: Sync?, selfId: number): { number }
	local ids: { number } = {}
	if sync == nil then
		return ids
	end
	for _, member in sync.members do
		if member.userId ~= selfId then
			table.insert(ids, member.userId)
		end
	end
	return ids
end

function PartyView.inviteText(from: string): string
	return from .. " invites you to their party"
end

return PartyView
