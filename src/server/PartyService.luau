--!strict
-- Parties (spec 3.14): asking the nearest player, the invite, joining, leaving, removing a
-- member and handing over the lead. Party holds every rule; this service owns the one live
-- state, tells the players what changed and installs who counts as an ally. Every handler
-- reads the state and stores the new one with no yielding call in between.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Party = require(ReplicatedStorage.Shared.Rules.Party)
local PartyView = require(ReplicatedStorage.Shared.Rules.PartyView)
local RateLimiter = require(ReplicatedStorage.Shared.Rules.RateLimiter)
local Trade = require(ReplicatedStorage.Shared.Rules.Trade)
local Types = require(ReplicatedStorage.Shared.Types)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)
local LedgerService = require(script.Parent.LedgerService)

type Invite = { from: Player, expiresAt: number }

local BUCKET_CAPACITY = 10
local BUCKET_REFILL_PER_SECOND = 5

local PartyService = {}

local state: Party.State = Party.new()
-- Every present player by UserId, so a member id can be turned back into a Player.
local players: { [number]: Player } = {}
-- Pending invites, keyed by the invited player.
local invites: { [Player]: Invite } = {}
-- Who each asker has asked.
local asked: { [Player]: Player } = {}
local buckets: { [Player]: RateLimiter.Bucket } = {}
local inviteRemote: RemoteEvent
local syncRemote: RemoteEvent

local function allowed(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if bucket == nil then
		bucket = RateLimiter.new(BUCKET_CAPACITY, now)
		buckets[player] = bucket
	end
	return RateLimiter.allow(bucket, now, BUCKET_CAPACITY, BUCKET_REFILL_PER_SECOND)
end

-- A message to someone who may already have left.
local function tell(player: Player, code: string, args: { [string]: string }?)
	if player.Parent == Players then
		LedgerService.notify(player, code, args)
	end
end

-- A message to a member by id, when they are still here.
local function tellId(userId: number, code: string, args: { [string]: string }?)
	local player = players[userId]
	if player ~= nil then
		tell(player, code, args)
	end
end

local function nameOf(userId: number): string
	local player = players[userId]
	return if player ~= nil then player.DisplayName else "A player"
end

local function vec(position: Vector3): Types.Vec3
	return { x = position.X, y = position.Y, z = position.Z }
end

-- Each present member gets the whole party, in join order.
local function sync(party: Party.Party)
	local members: { PartyView.Member } = {}
	for _, userId in party.members do
		table.insert(members, { userId = userId, name = nameOf(userId) })
	end
	local view: PartyView.Sync = { leader = party.leader, members = members }
	for _, userId in party.members do
		local player = players[userId]
		if player ~= nil and player.Parent == Players then
			syncRemote:FireClient(player, view)
		end
	end
end

local function unsync(player: Player)
	if player.Parent == Players then
		syncRemote:FireClient(player, nil)
	end
end

-- Removes an invite to `target`, from either table.
local function clearInvite(target: Player)
	local invite = invites[target]
	if invite == nil then
		return
	end
	invites[target] = nil
	if asked[invite.from] == target then
		asked[invite.from] = nil
	end
end

-- Tells whoever is left what happened when `removedId` went out of `before` (by their own
-- leave, an exit or a kick): the party broke up, or the rest hear `code` and any new leader.
local function announceRemoval(before: Party.Party, removedId: number, code: string)
	local remaining: { number } = {}
	for _, userId in before.members do
		if userId ~= removedId then
			table.insert(remaining, userId)
		end
	end
	local after = Party.find(state, remaining[1])
	if after == nil then
		for _, userId in remaining do
			tellId(userId, "PARTY_DISBANDED")
			local player = players[userId]
			if player ~= nil then
				unsync(player)
			end
		end
		return
	end
	local removedName = nameOf(removedId)
	for _, userId in remaining do
		tellId(userId, code, { player = removedName })
		if after.leader ~= before.leader then
			tellId(userId, "PARTY_NEW_LEADER", { player = nameOf(after.leader) })
		end
	end
	sync(after)
end

-- Takes a player out of their party. Returns the refusal code, or nil when it worked.
local function removeMember(userId: number, why: string): string?
	local before = Party.find(state, userId)
	local after, code = Party.leave(state, userId)
	if before == nil or after == nil then
		return code
	end
	state = after
	local leaver = players[userId]
	if why == "left" and leaver ~= nil then
		tell(leaver, "PARTY_LEFT")
		unsync(leaver)
	end
	announceRemoval(before, userId, "PARTY_MEMBER_LEFT")
	return nil
end

local function handleRequest(player: Player)
	if player.Parent ~= Players or not allowed(player) then
		return
	end
	local _, root = Fighters.body(player.UserId)
	-- A member who cannot invite hears why even when nobody else is in range.
	local own = Party.find(state, player.UserId)
	if own ~= nil and own.leader ~= player.UserId then
		LedgerService.notify(player, "PARTY_NOT_LEADER")
		return
	end
	if own ~= nil and #own.members >= Party.MAX_SIZE then
		LedgerService.notify(player, "PARTY_FULL")
		return
	end
	if
		DataService.get(player) == nil
		or root == nil
		or asked[player] ~= nil
		or invites[player] ~= nil
	then
		LedgerService.notify(player, "EDICT_NOT_NOW")
		return
	end
	-- The asker's own party mates are left out so one standing closest cannot hide a new player.
	local mates = Party.allies(state, player.UserId)
	local others: { Trade.Body } = {}
	for userId, other in players do
		if other ~= player and other.Parent == Players and table.find(mates, userId) == nil then
			local _, otherRoot = Fighters.body(userId)
			if otherRoot ~= nil then
				table.insert(others, { userId = userId, position = vec(otherRoot.Position) })
			end
		end
	end
	local targetId =
		Trade.nearest({ userId = player.UserId, position = vec(root.Position) }, others)
	local target = if targetId ~= nil then players[targetId] else nil
	if target == nil then
		LedgerService.notify(player, "EDICT_NO_TARGET")
		return
	end
	local can, code = Party.canInvite(state, player.UserId, target.UserId)
	if not can then
		LedgerService.notify(player, code, { player = target.DisplayName })
		return
	end
	if DataService.get(target) == nil or invites[target] ~= nil or asked[target] ~= nil then
		LedgerService.notify(player, "PARTY_BUSY", { player = target.DisplayName })
		return
	end

	local invite: Invite = { from = player, expiresAt = os.clock() + Party.INVITE_SECONDS }
	invites[target] = invite
	asked[player] = target
	inviteRemote:FireClient(target, { from = player.DisplayName, seconds = Party.INVITE_SECONDS })
	LedgerService.notify(player, "PARTY_INVITE_SENT", { player = target.DisplayName })
	task.delay(Party.INVITE_SECONDS, function()
		if invites[target] ~= invite then
			return
		end
		clearInvite(target)
		if target.Parent == Players then
			inviteRemote:FireClient(target, nil)
		end
		tell(player, "PARTY_EXPIRED")
	end)
end

local function handleReply(player: Player, accept: any)
	if player.Parent ~= Players or not allowed(player) then
		return
	end
	local invite = invites[player]
	if invite == nil then
		LedgerService.notify(player, "PARTY_NO_INVITE")
		return
	end
	clearInvite(player)
	local asker = invite.from
	if accept ~= true then
		tell(asker, "PARTY_DECLINED", { player = player.DisplayName })
		return
	end
	if asker.Parent ~= Players then
		LedgerService.notify(player, "PARTY_NO_INVITE")
		return
	end
	local joined = Party.join(state, asker.UserId, player.UserId)
	if joined == nil then
		-- The invitee hears it in their own words, naming the asker.
		LedgerService.notify(player, "PARTY_JOIN_FAILED", { player = asker.DisplayName })
		return
	end
	state = joined
	local party = Party.find(state, player.UserId)
	if party == nil then
		return
	end
	tell(player, "PARTY_JOINED", { player = nameOf(party.leader) })
	for _, userId in party.members do
		if userId ~= player.UserId then
			tellId(userId, "PARTY_MEMBER_JOINED", { player = player.DisplayName })
		end
	end
	sync(party)
end

local function handleAction(player: Player, raw: any)
	if player.Parent ~= Players or not allowed(player) then
		return
	end
	if type(raw) ~= "table" or type(raw.kind) ~= "string" then
		LedgerService.notify(player, "BAD_REQUEST")
		return
	end
	local kind = raw.kind
	if kind == "leave" then
		local code = removeMember(player.UserId, "left")
		if code ~= nil then
			LedgerService.notify(player, code)
		end
	elseif kind == "kick" then
		local before = Party.find(state, player.UserId)
		local after, code = Party.kick(state, player.UserId, raw.userId)
		if after == nil or before == nil then
			LedgerService.notify(player, code)
			return
		end
		state = after
		local removed = players[raw.userId]
		if removed ~= nil then
			tell(removed, "PARTY_KICKED", { player = player.DisplayName })
			unsync(removed)
		end
		announceRemoval(before, raw.userId, "PARTY_MEMBER_KICKED")
	elseif kind == "promote" then
		local after, code = Party.promote(state, player.UserId, raw.userId)
		if after == nil then
			LedgerService.notify(player, code)
			return
		end
		state = after
		local party = Party.find(state, player.UserId)
		if party == nil then
			return
		end
		for _, userId in party.members do
			tellId(userId, "PARTY_NEW_LEADER", { player = nameOf(party.leader) })
		end
		sync(party)
	else
		LedgerService.notify(player, "BAD_REQUEST")
	end
end

-- Runs through DataService.beforeRelease, after CombatService's combat-log credit.
local function onExit(player: Player)
	removeMember(player.UserId, "exit")
	-- An invite to them is dropped; an invite from them is withdrawn from whoever was shown it.
	clearInvite(player)
	local target = asked[player]
	if target ~= nil then
		asked[player] = nil
		local sent = invites[target]
		if sent ~= nil and sent.from == player then
			invites[target] = nil
			if target.Parent == Players then
				inviteRemote:FireClient(target, nil)
			end
		end
	end
	buckets[player] = nil
	-- Leave a rejoin under the same UserId alone.
	if players[player.UserId] == player then
		players[player.UserId] = nil
	end
end

-- Play-test seam: a copy of the player's party (user ids), if any.
function PartyService.party(player: Player): Party.Party?
	return Party.find(state, player.UserId)
end

function PartyService.start()
	inviteRemote = LedgerService.makeRemote(Net.PartyInvite)
	syncRemote = LedgerService.makeRemote(Net.PartySync)
	LedgerService.makeRemote(Net.PartyRequest).OnServerEvent:Connect(handleRequest)
	LedgerService.makeRemote(Net.PartyReply).OnServerEvent:Connect(handleReply)
	LedgerService.makeRemote(Net.PartyAction).OnServerEvent:Connect(handleAction)

	-- Reads the live `state`, so every replacement is seen.
	Fighters.setAllies(function(id: number): { number }
		return Party.allies(state, id)
	end)

	for _, player in Players:GetPlayers() do
		players[player.UserId] = player
	end
	Players.PlayerAdded:Connect(function(player: Player)
		players[player.UserId] = player
	end)
	DataService.beforeRelease(onExit)
end

return PartyService
