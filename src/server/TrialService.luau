--!strict
-- The Wardens' trials and the Unpaid Debt quest. TrialRun holds every rule; this service
-- owns the running trials, checks every request itself (who, where, when), watches the
-- clock, the markers and creature defeats, and pays out through Payout.
-- A client only ever says "I accept trial X": distance, progress, time and rewards are the
-- server's. No yielding call sits between reading a run or record and writing it back.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ledger = require(ReplicatedStorage.Shared.Rules.Ledger)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Rules.RateLimiter)
local TrialRun = require(ReplicatedStorage.Shared.Rules.TrialRun)
local TrialView = require(ReplicatedStorage.Shared.Rules.TrialView)
local Trials = require(ReplicatedStorage.Shared.Catalog.Trials)
local Types = require(ReplicatedStorage.Shared.Types)
local World = require(ReplicatedStorage.Shared.Catalog.World)
local CreatureService = require(script.Parent.CreatureService)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)
local LedgerService = require(script.Parent.LedgerService)
local Payout = require(script.Parent.Payout)
local SourceService = require(script.Parent.SourceService)

type Active = {
	run: TrialRun.Run,
	parcel: Instance?,
	championId: number?,
	died: RBXScriptConnection?,
}

local BUCKET_CAPACITY = 10
local BUCKET_REFILL_PER_SECOND = 5
local TICK_SECONDS = 0.1
local WARDEN_TAG = "Warden"
local ROOT_LIFT = 3 -- a standing character's root above the ground
local COLOSSUS = "brine_colossus"
local QUEST_COLOSSUS = "colossus"
local PARCEL_COLOR = Color3.fromRGB(140, 100, 60)

local TrialService = {}

local runs: { [Player]: Active } = {}
local buckets: { [Player]: RateLimiter.Bucket } = {}
local offerRemote: RemoteEvent
local syncRemote: RemoteEvent
local accumulated = 0
-- Run timers and trial cooldowns. Replaced by the play test to skip time.
local clock: () -> number = os.clock
local realClock: () -> number = os.time

local function allowed(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if bucket == nil then
		bucket = RateLimiter.new(BUCKET_CAPACITY, now)
		buckets[player] = bucket
	end
	return RateLimiter.allow(bucket, now, BUCKET_CAPACITY, BUCKET_REFILL_PER_SECOND)
end

-- Free slots the player can still fill: none while their Ledger is locked.
local function room(player: Player, data: Types.PlayerData): number
	if LedgerService.isLocked(player) then
		return 0
	end
	return math.max(0, Ledger.FREE_SLOTS - #data.ledger.free)
end

local function sync(player: Player)
	if player.Parent ~= Players then
		return
	end
	local data = DataService.get(player)
	if data == nil then
		return
	end
	local active = runs[player]
	local state: TrialView.HudState? = nil
	if active ~= nil then
		state = {
			trialId = active.run.trialId,
			progress = active.run.progress,
			goal = active.run.goal,
			secondsLeft = active.run.endsAt - clock(),
		}
	end
	syncRemote:FireClient(player, state, data.trials.questStep)
end

-- A quest step: a passed trial's id, or "colossus". Only the next step counts.
local function questEvent(player: Player, data: Types.PlayerData, event: string)
	local step, completed = TrialRun.advanceQuest(data.trials.questStep, event)
	if step == data.trials.questStep and not completed then
		return
	end
	data.trials = { cooldowns = data.trials.cooldowns, questStep = step }
	local quest = Trials.quest
	if completed then
		LedgerService.notify(player, "QUEST_COMPLETE", { coin = tostring(quest.coin) })
		Payout.give(player, {
			coin = quest.coin,
			xp = quest.xp,
			path = Payout.calling(player),
			relics = { quest.relicId },
		})
	else
		LedgerService.notify(player, "QUEST_STEP", { n = tostring(step) })
	end
end

-- The one way a trial ends: pass, timeout, defeat or leaving. Clears the run with its parcel
-- and champion, starts the cooldown, pays a pass, and tells the player. `failCode` is the
-- message for a failure; nil says nothing (the player is leaving).
local function endRun(player: Player, passed: boolean, failCode: string?)
	local active = runs[player]
	if active == nil then
		return
	end
	runs[player] = nil
	if active.died ~= nil then
		active.died:Disconnect()
	end
	if active.parcel ~= nil then
		active.parcel:Destroy()
	end
	if active.championId ~= nil then
		CreatureService.despawn(active.championId)
	end

	local trial = Trials.byId[active.run.trialId]
	local data = DataService.get(player)
	if data ~= nil then
		data.trials = TrialRun.finish(data.trials, active.run.trialId, passed, realClock())
	end
	if trial == nil then
		return
	end
	if passed and data ~= nil then
		LedgerService.notify(
			player,
			"TRIAL_PASSED",
			{ name = trial.name, coin = tostring(trial.coin) }
		)
		-- Coin and XP are paid even when the Relic is sealed or there is no room for it.
		Payout.give(player, {
			coin = trial.coin,
			xp = trial.xp,
			path = Payout.calling(player),
			relics = { trial.relicId },
		})
		questEvent(player, data, trial.id)
	elseif failCode ~= nil then
		LedgerService.notify(player, failCode, { name = trial.name })
	end
	sync(player)
end

local function giveParcel(root: BasePart): Instance
	local parcel = Instance.new("Part")
	parcel.Name = "Parcel"
	parcel.Size = Vector3.new(1.5, 1.2, 1.5)
	parcel.Color = PARCEL_COLOR
	parcel.Material = Enum.Material.Wood
	parcel.Massless = true
	parcel.CanCollide = false
	parcel.CanQuery = false
	parcel.CanTouch = false
	parcel.CFrame = root.CFrame * CFrame.new(0, 0.4, 1.3)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = parcel
	weld.Parent = parcel
	parcel.Parent = root.Parent
	return parcel
end

local function showOffer(player: Player, trialId: string)
	local data = DataService.get(player)
	local trial = Trials.byId[trialId]
	if data == nil then
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return
	end
	if trial == nil then
		return
	end
	local active = runs[player]
	offerRemote:FireClient(
		player,
		TrialView.offer(
			trial.id,
			data.trials,
			if active ~= nil then active.run.trialId else nil,
			realClock(),
			SourceService.held(trial.relicId),
			room(player, data)
		)
	)
end

-- The client names a trial; everything else is checked here, in order: data, a known trial,
-- standing by its Warden, no trial running, no cooldown. Nothing starts on a refusal.
local function handleAccept(player: Player, rawId: any)
	if player.Parent ~= Players or not allowed(player) then
		return
	end
	local data = DataService.get(player)
	if data == nil then
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return
	end
	local trial = if type(rawId) == "string" then Trials.byId[rawId] else nil
	if trial == nil then
		LedgerService.notify(player, "BAD_REQUEST")
		return
	end
	local humanoid, root = Fighters.body(player.UserId)
	local warden = World.wardens[trial.id]
	if humanoid == nil or root == nil or warden == nil then
		LedgerService.notify(player, "TOO_FAR")
		return
	end
	local distance = (root.Position - Vector3.new(warden.x, warden.y + ROOT_LIFT, warden.z)).Magnitude
	-- Written positively so a NaN distance is refused.
	if not (distance <= TrialRun.WARDEN_REACH) then
		LedgerService.notify(player, "TOO_FAR")
		return
	end

	local current = runs[player]
	local run, code = TrialRun.start(
		data.trials,
		if current ~= nil then current.run else nil,
		trial.id,
		clock(),
		realClock()
	)
	if run == nil then
		if code == "TRIAL_COOLDOWN" then
			local left = TrialRun.cooldownLeft(data.trials, trial.id, realClock())
			LedgerService.notify(
				player,
				code,
				{ name = trial.name, seconds = tostring(math.ceil(left)) }
			)
		else
			LedgerService.notify(player, code)
		end
		return
	end

	local active: Active = { run = run }
	runs[player] = active
	if trial.kind == "delivery" then
		active.parcel = giveParcel(root)
	elseif trial.kind == "duel" then
		active.championId = CreatureService.spawnChampion(player, World.duelArena)
	end
	-- Any defeat during a trial fails it.
	active.died = humanoid.Died:Connect(function()
		if runs[player] == active then
			endRun(player, false, "TRIAL_FAILED_DEFEAT")
		end
	end)
	LedgerService.notify(player, "TRIAL_STARTED", { name = trial.name })
	sync(player)
end

local function tickRun(player: Player, active: Active)
	local run = active.run
	if TrialRun.isExpired(run, clock()) then
		endRun(player, false, "TRIAL_FAILED_TIME")
		return
	end
	local trial = Trials.byId[run.trialId]
	local _, root = Fighters.body(player.UserId)
	if trial == nil or root == nil then
		return
	end
	if trial.kind == "course" then
		local markers = World.courses[trial.id]
		local marker = if markers ~= nil then markers[run.progress + 1] else nil
		if marker ~= nil then
			local gap = (root.Position - Vector3.new(marker.x, marker.y, marker.z)).Magnitude
			if gap <= TrialRun.MARKER_RADIUS then
				active.run = TrialRun.reachMarker(run, run.progress + 1)
				LedgerService.notify(player, "MARKER_REACHED", {
					n = tostring(active.run.progress),
					total = tostring(active.run.goal),
				})
				sync(player)
			end
		end
	elseif trial.kind == "delivery" then
		local harbour = World.harbour
		local gap = (root.Position - Vector3.new(harbour.x, harbour.y + ROOT_LIFT, harbour.z)).Magnitude
		if gap <= TrialRun.DELIVERY_RADIUS then
			active.run = TrialRun.complete(run)
		end
	end
	if TrialRun.isPassed(active.run) then
		endRun(player, true, nil)
	end
end

local function onHeartbeat(deltaTime: number)
	accumulated += deltaTime
	if accumulated < TICK_SECONDS then
		return
	end
	accumulated = 0
	-- A copy: a trial ending mid-tick must not change the table under us.
	for player, active in table.clone(runs) do
		if runs[player] ~= active then
			continue
		end
		local ok, err = pcall(tickRun, player, active)
		if not ok then
			warn(`[IsleOfAvarice] TrialService tick failed: {err}`)
		end
	end
end

-- Hunts count a creature the player helped defeat; a duel ends when the duellist's champion
-- falls; the Brine Colossus is the quest's last step for everyone who helped.
local function onCreatureDefeated(
	kind: string,
	id: number,
	contributors: { Player },
	owner: Player?
)
	for _, player in contributors do
		local active = runs[player]
		if active ~= nil then
			local counted = TrialRun.countDefeat(active.run, kind)
			if counted.progress ~= active.run.progress then
				active.run = counted
				LedgerService.notify(player, "HUNT_PROGRESS", {
					n = tostring(counted.progress),
					total = tostring(counted.goal),
				})
				if TrialRun.isPassed(counted) then
					endRun(player, true, nil)
				else
					sync(player)
				end
			end
		end
	end
	if owner ~= nil then
		local active = runs[owner]
		if active ~= nil and active.championId == id then
			-- It is already gone: nothing left to despawn.
			active.championId = nil
			active.run = TrialRun.complete(active.run)
			if TrialRun.isPassed(active.run) then
				endRun(owner, true, nil)
			end
		end
	end
	if kind == COLOSSUS then
		for _, player in contributors do
			local data = DataService.get(player)
			if data ~= nil then
				questEvent(player, data, QUEST_COLOSSUS)
				sync(player)
			end
		end
	end
end

local function connectWarden(instance: Instance)
	local trialId = instance:GetAttribute("TrialId")
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if type(trialId) ~= "string" or prompt == nil then
		return
	end
	prompt.Triggered:Connect(function(player: Player)
		showOffer(player, trialId)
	end)
end

-- Sends the player their TrialSync now (used after a Renounce restarts the quest).
function TrialService.resync(player: Player)
	sync(player)
end

-- Play-test seam: the player's running trial, if any.
function TrialService.run(player: Player): TrialRun.Run?
	local active = runs[player]
	return if active ~= nil then active.run else nil
end

-- Play-test seam: the clocks for run timers (default os.clock) and cooldowns (os.time).
function TrialService.setClocks(runClock: () -> number, cooldownClock: () -> number)
	clock = runClock
	realClock = cooldownClock
end

function TrialService.start()
	offerRemote = LedgerService.makeRemote(Net.TrialOffer)
	syncRemote = LedgerService.makeRemote(Net.TrialSync)
	LedgerService.makeRemote(Net.TrialAccept).OnServerEvent:Connect(handleAccept)

	for _, instance in CollectionService:GetTagged(WARDEN_TAG) do
		connectWarden(instance)
	end
	CollectionService:GetInstanceAddedSignal(WARDEN_TAG):Connect(connectWarden)

	CreatureService.onDefeated(onCreatureDefeated)
	DataService.onLoaded(function(player)
		sync(player)
	end)
	-- Leaving fails the trial quietly, so its cooldown is saved before the profile closes.
	DataService.beforeRelease(function(player)
		endRun(player, false, nil)
	end)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return TrialService
