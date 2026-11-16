--!strict
-- Player-to-player trades (spec 3.13): asking the nearest player, the invite, the two offers,
-- the two confirmations and the swap. Trade holds every rule; this service owns the sessions,
-- watches that both traders stay close and well, and settles. The swap writes both Ledgers
-- and both Coin totals in one step: no yielding call from reading both players' data to the
-- last write, so it fully happens or does not happen at all.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EdictRules = require(ReplicatedStorage.Shared.Rules.EdictRules)
local Net = require(ReplicatedStorage.Shared.Net)
local Protection = require(ReplicatedStorage.Shared.Rules.Protection)
local RateLimiter = require(ReplicatedStorage.Shared.Rules.RateLimiter)
local Trade = require(ReplicatedStorage.Shared.Rules.Trade)
local Types = require(ReplicatedStorage.Shared.Types)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)
local LedgerService = require(script.Parent.LedgerService)
local ProtectionService = require(script.Parent.ProtectionService)
local SourceService = require(script.Parent.SourceService)

-- Both traders map to the same Ref; `session` is replaced as the trade changes.
type Ref = { session: Trade.Session, a: Player, b: Player }
type Invite = { from: Player }

local BUCKET_CAPACITY = 10
local BUCKET_REFILL_PER_SECOND = 5
local WATCH_SECONDS = 0.5

local TradeService = {}

-- Pending invites, keyed by the invited player.
local invites: { [Player]: Invite } = {}
-- Who each asker has asked.
local asked: { [Player]: Player } = {}
local trades: { [Player]: Ref } = {}
local buckets: { [Player]: RateLimiter.Bucket } = {}
local inviteRemote: RemoteEvent
local syncRemote: RemoteEvent
local accumulated = 0

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

local function vec(position: Vector3): Types.Vec3
	return { x = position.X, y = position.Y, z = position.Z }
end

-- Present, data loaded, alive and not locked: able to take part in a trade at all.
local function fit(player: Player): boolean
	if player.Parent ~= Players or DataService.get(player) == nil then
		return false
	end
	if LedgerService.isLocked(player) then
		return false
	end
	local _, root = Fighters.body(player.UserId)
	return root ~= nil
end

-- Not Marked and not just out of a fight (and so not moving cards out of a blind claim's
-- reach). A player with no loaded data is not told more than "not now".
local function canDealNow(player: Player): (boolean, string)
	local now = os.clock()
	local status = ProtectionService.status(player, now)
	if status == nil then
		return false, "EDICT_NOT_NOW"
	end
	local ok, code = EdictRules.canDeal({
		marked = Protection.isMarked(status, now),
		lastFightAt = CombatService.lastFightAt(player),
	}, now)
	return ok, code or "EDICT_NOT_NOW"
end

local function freeToTrade(player: Player): boolean
	return fit(player) and trades[player] == nil and invites[player] == nil and asked[player] == nil
end

-- Written positively so a NaN distance counts as too far.
local function withinKeepRange(a: Player, b: Player): boolean
	local _, rootA = Fighters.body(a.UserId)
	local _, rootB = Fighters.body(b.UserId)
	if rootA == nil or rootB == nil then
		return false
	end
	return (rootA.Position - rootB.Position).Magnitude <= Trade.KEEP_RANGE
end

-- Each trader gets their own view of the trade.
local function sync(ref: Ref)
	for _, pair in { { ref.a, ref.b }, { ref.b, ref.a } } do
		local player, other = pair[1], pair[2]
		local data = DataService.get(player)
		if player.Parent == Players and data ~= nil then
			syncRemote:FireClient(
				player,
				Trade.view(
					ref.session,
					player.UserId,
					other.DisplayName,
					data.ledger,
					data.coin,
					os.clock()
				)
			)
		end
	end
end

local function closeWindow(player: Player)
	if player.Parent == Players then
		syncRemote:FireClient(player, nil)
	end
end

-- Ends the trade with nothing swapped and tells whoever is still here.
local function cancel(ref: Ref)
	if trades[ref.a] ~= ref and trades[ref.b] ~= ref then
		return
	end
	if trades[ref.a] == ref then
		trades[ref.a] = nil
	end
	if trades[ref.b] == ref then
		trades[ref.b] = nil
	end
	for _, player in { ref.a, ref.b } do
		tell(player, "TRADE_CANCELLED")
		closeWindow(player)
	end
end

local function settle(ref: Ref)
	local a, b = ref.a, ref.b
	local dataA, dataB = DataService.get(a), DataService.get(b)
	if
		dataA == nil
		or dataB == nil
		or a.Parent ~= Players
		or b.Parent ~= Players
		or LedgerService.isLocked(a)
		or LedgerService.isLocked(b)
		or not fit(a)
		or not fit(b)
		or not withinKeepRange(a, b)
		-- The early confirmer may have started a fight since: cards must not move then.
		or not canDealNow(a)
		or not canDealNow(b)
	then
		cancel(ref)
		return
	end
	-- No yielding call from here to the last write: neither Ledger can go stale.
	local ledgerA, coinA, ledgerB, coinB, code =
		Trade.settle(ref.session, dataA.ledger, dataA.coin, dataB.ledger, dataB.coin)
	if ledgerA == nil or ledgerB == nil then
		tell(a, code)
		tell(b, code)
		ref.session = Trade.unconfirm(ref.session, os.clock())
		sync(ref)
		return
	end
	local heldA, heldB = dataA.coin, dataB.coin
	-- Out of `trades` first, so the Ledger-changed hook below does nothing.
	trades[a] = nil
	trades[b] = nil
	LedgerService.set(a, ledgerA)
	LedgerService.set(b, ledgerB)
	SourceService.addCoin(a, coinA - heldA)
	SourceService.addCoin(b, coinB - heldB)
	tell(a, "TRADE_DONE")
	tell(b, "TRADE_DONE")
	closeWindow(a)
	closeWindow(b)
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

local function handleRequest(player: Player)
	if player.Parent ~= Players or not allowed(player) then
		return
	end
	if not freeToTrade(player) then
		LedgerService.notify(player, "EDICT_NOT_NOW")
		return
	end
	local canDeal, dealCode = canDealNow(player)
	if not canDeal then
		LedgerService.notify(player, dealCode)
		return
	end
	local _, root = Fighters.body(player.UserId)
	if root == nil then
		LedgerService.notify(player, "EDICT_NOT_NOW")
		return
	end
	local others: { Trade.Body } = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local _, otherRoot = Fighters.body(other.UserId)
			if otherRoot ~= nil then
				table.insert(others, { userId = other.UserId, position = vec(otherRoot.Position) })
			end
		end
	end
	local targetId =
		Trade.nearest({ userId = player.UserId, position = vec(root.Position) }, others)
	local target = if targetId ~= nil then Players:GetPlayerByUserId(targetId) else nil
	if target == nil then
		LedgerService.notify(player, "EDICT_NO_TARGET")
		return
	end
	if not freeToTrade(target) then
		LedgerService.notify(player, "TRADE_BUSY", { player = target.DisplayName })
		return
	end

	local invite: Invite = { from = player }
	invites[target] = invite
	asked[player] = target
	inviteRemote:FireClient(target, { from = player.DisplayName, seconds = Trade.INVITE_SECONDS })
	LedgerService.notify(player, "TRADE_SENT", { player = target.DisplayName })
	task.delay(Trade.INVITE_SECONDS, function()
		if invites[target] ~= invite then
			return
		end
		clearInvite(target)
		if target.Parent == Players then
			inviteRemote:FireClient(target, nil)
		end
		tell(player, "TRADE_EXPIRED")
	end)
end

local function handleReply(player: Player, accept: any)
	if player.Parent ~= Players or not allowed(player) then
		return
	end
	local invite = invites[player]
	if invite == nil then
		LedgerService.notify(player, "TRADE_NOT_OPEN")
		return
	end
	clearInvite(player)
	local asker = invite.from
	if accept ~= true then
		tell(asker, "TRADE_DECLINED", { player = player.DisplayName })
		return
	end
	if not fit(asker) or not fit(player) or not withinKeepRange(asker, player) then
		tell(asker, "TRADE_CANCELLED")
		tell(player, "TRADE_CANCELLED")
		return
	end
	-- The accepter hears their own reason; the asker's reason is not shared. The asker is
	-- always told the trade is off.
	local canDeal, dealCode = canDealNow(player)
	if not canDeal then
		tell(player, dealCode)
		tell(asker, "TRADE_CANCELLED")
		return
	end
	if not canDealNow(asker) then
		tell(asker, "TRADE_CANCELLED")
		tell(player, "TRADE_CANCELLED")
		return
	end
	local ref: Ref = {
		session = Trade.new(asker.UserId, player.UserId, os.clock()),
		a = asker,
		b = player,
	}
	trades[asker] = ref
	trades[player] = ref
	sync(ref)
end

local function handleAction(player: Player, raw: any)
	if player.Parent ~= Players or not allowed(player) then
		return
	end
	local ref = trades[player]
	if ref == nil then
		LedgerService.notify(player, "TRADE_NOT_OPEN")
		return
	end
	if type(raw) ~= "table" or type(raw.kind) ~= "string" then
		LedgerService.notify(player, "BAD_REQUEST")
		return
	end
	local kind = raw.kind
	if kind ~= "cancel" then
		-- A dead or locked trader cannot act; the watch ends the trade shortly.
		local _, root = Fighters.body(player.UserId)
		if root == nil then
			LedgerService.notify(player, "EDICT_NOT_NOW")
			return
		end
		if LedgerService.isLocked(player) then
			LedgerService.notify(player, "LEDGER_LOCKED")
			return
		end
	end
	if kind == "offer" then
		local data = DataService.get(player)
		local session, code = Trade.setOffer(
			ref.session,
			player.UserId,
			raw,
			if data ~= nil then data.ledger else nil,
			if data ~= nil then data.coin else 0,
			os.clock()
		)
		if session == nil then
			LedgerService.notify(player, code)
			return
		end
		ref.session = session
		sync(ref)
	elseif kind == "confirm" then
		local canDeal, dealCode = canDealNow(player)
		if not canDeal then
			LedgerService.notify(player, dealCode)
			return
		end
		local session, code = Trade.confirm(ref.session, player.UserId, os.clock())
		if session == nil then
			LedgerService.notify(player, code)
			return
		end
		ref.session = session
		if Trade.ready(session) then
			settle(ref)
		else
			sync(ref)
		end
	elseif kind == "cancel" then
		cancel(ref)
	else
		LedgerService.notify(player, "BAD_REQUEST")
	end
end

-- A trade ends when a trader is gone, dead, locked, or has walked too far from the other.
local function watch()
	for _, ref in table.clone(trades) do
		if trades[ref.a] ~= ref and trades[ref.b] ~= ref then
			continue
		end
		if not fit(ref.a) or not fit(ref.b) or not withinKeepRange(ref.a, ref.b) then
			cancel(ref)
		end
	end
end

local function onHeartbeat(deltaTime: number)
	accumulated += deltaTime
	if accumulated < WATCH_SECONDS then
		return
	end
	accumulated = 0
	local ok, err = pcall(watch)
	if not ok then
		warn(`[IsleOfAvarice] TradeService watch failed: {err}`)
	end
end

-- Something else changed a trader's Ledger: an offer they can no longer cover is emptied.
local function onLedgerChanged(player: Player, ledger: Types.Ledger)
	local ref = trades[player]
	local data = DataService.get(player)
	if ref == nil or data == nil then
		return
	end
	ref.session = Trade.prune(ref.session, player.UserId, ledger, data.coin, os.clock())
	sync(ref)
end

local function onRemoving(player: Player)
	local ref = trades[player]
	if ref ~= nil then
		cancel(ref)
	end
	-- An invite to them: the asker is told it is off.
	local invite = invites[player]
	if invite ~= nil then
		tell(invite.from, "TRADE_CANCELLED")
	end
	clearInvite(player)
	-- An invite from them: withdrawn from whoever was shown it.
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
end

-- Play-test seam: the player's trade session, if any.
function TradeService.session(player: Player): Trade.Session?
	local ref = trades[player]
	return if ref ~= nil then ref.session else nil
end

function TradeService.start()
	inviteRemote = LedgerService.makeRemote(Net.TradeInvite)
	syncRemote = LedgerService.makeRemote(Net.TradeSync)
	LedgerService.makeRemote(Net.TradeRequest).OnServerEvent:Connect(handleRequest)
	LedgerService.makeRemote(Net.TradeReply).OnServerEvent:Connect(handleReply)
	LedgerService.makeRemote(Net.TradeAction).OnServerEvent:Connect(handleAction)

	LedgerService.onChanged(onLedgerChanged)
	Players.PlayerRemoving:Connect(onRemoving)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return TradeService
