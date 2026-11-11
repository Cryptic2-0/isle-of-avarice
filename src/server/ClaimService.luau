--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlindClaim = require(ReplicatedStorage.Shared.Rules.BlindClaim)
local Net = require(ReplicatedStorage.Shared.Net)
local Protection = require(ReplicatedStorage.Shared.Rules.Protection)
local RateLimiter = require(ReplicatedStorage.Shared.Rules.RateLimiter)
local Relics = require(ReplicatedStorage.Shared.Catalog.Relics)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local LedgerService = require(script.Parent.LedgerService)

local BUCKET_CAPACITY = 10
local BUCKET_REFILL_PER_SECOND = 5

local ClaimService = {}

local startedCallbacks: { (killer: Player, victim: Player) -> () } = {}

-- Registers a callback that runs (each in pcall) right after a claim opens.
function ClaimService.onClaimStarted(callback: (killer: Player, victim: Player) -> ())
	table.insert(startedCallbacks, callback)
end

-- One open claim, made by `killer` on `victim`. Names are kept because either may leave.
type Session = {
	killer: Player,
	victim: Player,
	killerName: string,
	victimName: string,
	claim: BlindClaim.Claim,
	release: () -> (),
	closed: boolean,
}

-- Open claims by killer. A killer has at most one; a victim is in at most one (they are locked).
local sessions: { [Player]: Session } = {}
-- Last claim time per killer and victim (UserIds), on the os.clock() clock.
local history: Protection.ClaimHistory = {}
local buckets: { [Player]: RateLimiter.Bucket } = {}
local claimUpdate: RemoteEvent

-- True if the player has a token left in their rate-limit bucket (takes one).
local function allowed(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if bucket == nil then
		bucket = RateLimiter.new(BUCKET_CAPACITY, now)
		buckets[player] = bucket
	end
	return RateLimiter.allow(bucket, now, BUCKET_CAPACITY, BUCKET_REFILL_PER_SECOND)
end

local function sendUpdate(session: Session)
	if session.killer.Parent ~= Players then
		return
	end
	claimUpdate:FireClient(session.killer, {
		victimName = session.victimName,
		claim = session.claim,
		secondsLeft = math.max(0, session.claim.expiresAt - os.clock()),
	})
end

-- Ends a claim. Every path that ends a claim comes here; it runs once only.
local function close(session: Session)
	if session.closed then
		return
	end
	session.closed = true
	if sessions[session.killer] == session then
		sessions[session.killer] = nil
	end

	LedgerService.unlock(session.victim)
	session.release()

	if session.killer.Parent == Players then
		claimUpdate:FireClient(session.killer, nil)
		LedgerService.notify(session.killer, "CLAIM_OVER")
	end
	if session.victim.Parent == Players then
		local names: { string } = {}
		for _, id in session.claim.takenIds do
			local relic = Relics.byId[id]
			table.insert(names, if relic ~= nil then relic.name else id)
		end
		if #names > 0 then
			LedgerService.notify(session.victim, "CLAIM_LOST", {
				player = session.killerName,
				names = table.concat(names, ", "),
			})
		else
			LedgerService.notify(session.victim, "CLAIM_SAFE", { player = session.killerName })
		end
	end
end

-- Runs in the thread that reported the defeat. For a combat log that is the leaver's
-- PlayerRemoving, so the hold is taken before their profile can be released.
local function onDefeat(killer: Player, victim: Player)
	if sessions[killer] ~= nil or LedgerService.isLocked(victim) then
		return
	end
	if LedgerService.get(killer) == nil or LedgerService.get(victim) == nil then
		return
	end
	local now = os.clock()
	if not Protection.canClaim(history, killer.UserId, victim.UserId, now) then
		if killer.Parent == Players then
			LedgerService.notify(killer, "CLAIM_COOLDOWN", { player = victim.DisplayName })
		end
		return
	end

	history = Protection.recordClaim(history, killer.UserId, victim.UserId, now)
	local session: Session = {
		killer = killer,
		victim = victim,
		killerName = killer.DisplayName,
		victimName = victim.DisplayName,
		claim = BlindClaim.start(now),
		release = DataService.hold(victim),
		closed = false,
	}
	LedgerService.lock(victim)
	sessions[killer] = session

	if victim.Parent == Players then
		LedgerService.notify(victim, "DEFEATED_BY", { player = session.killerName })
	end
	LedgerService.notify(killer, "CLAIM_STARTED", { player = session.victimName })
	sendUpdate(session)
	for _, callback in startedCallbacks do
		local ok, err = pcall(callback, killer, victim)
		if not ok then
			warn(`[IsleOfAvarice] onClaimStarted callback failed: {err}`)
		end
	end

	task.delay(BlindClaim.DURATION, close, session)
end

local function handlePick(player: Player, slot: any)
	if player.Parent ~= Players then
		return
	end
	if not allowed(player) then
		return
	end
	local session = sessions[player]
	if session == nil or session.closed then
		return
	end

	-- Read both sides and check both are loaded before writing either.
	-- No yielding call from here to the two writes.
	local victimLedger = LedgerService.get(session.victim)
	local victimVault = LedgerService.getVault(session.victim)
	local killerLedger = LedgerService.get(player)
	if victimLedger == nil or victimVault == nil or killerLedger == nil then
		close(session)
		return
	end

	local now = os.clock()
	local claim, newVictim, newKiller, code, cardId =
		BlindClaim.pick(session.claim, victimLedger, victimVault, killerLedger, slot, now)

	-- The new claim is stored only once the card has moved, so a failed write records nothing.
	if code == "TAKEN" then
		if not LedgerService.set(session.victim, newVictim) then
			close(session)
			return
		end
		if not LedgerService.set(player, newKiller) then
			-- Cannot happen after the check above; if it does, give the card back.
			LedgerService.set(session.victim, victimLedger)
			close(session)
			return
		end
		session.claim = claim
		local relic = if cardId ~= nil then Relics.byId[cardId] else nil
		LedgerService.notify(
			player,
			"CLAIM_TAKEN",
			{ name = if relic ~= nil then relic.name else "" }
		)
	elseif code == "MISS" then
		session.claim = claim
		LedgerService.notify(player, "CLAIM_MISS")
	else
		-- A refusal returns the claim unchanged and spends no pick.
		LedgerService.notify(player, code)
	end

	sendUpdate(session)
	if not BlindClaim.isOpen(session.claim, now) then
		close(session)
	end
end

function ClaimService.start()
	claimUpdate = LedgerService.makeRemote(Net.ClaimUpdate)
	local claimPick = LedgerService.makeRemote(Net.ClaimPick)
	claimPick.OnServerEvent:Connect(handlePick)

	CombatService.onDefeat(onDefeat)

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		-- A leaving killer's claim ends. A leaving victim's claim goes on: their profile is held.
		local session = sessions[player]
		if session ~= nil then
			close(session)
		end
	end)
end

return ClaimService
