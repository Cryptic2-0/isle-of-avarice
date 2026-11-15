--!strict
-- A Warden's trial as a state machine: starting, progress, the clock, cooldowns, and the
-- Unpaid Debt quest. Run timers use os.clock(); cooldowns use os.time() and are saved.
local Trials = require("../Catalog/Trials")
local Types = require("../Types")
local World = require("../Catalog/World")

type TrialRecord = Types.TrialRecord

export type Run = { trialId: string, endsAt: number, progress: number, goal: number }

local TrialRun = {}

TrialRun.PASS_COOLDOWN = 300
TrialRun.FAIL_COOLDOWN = 30
TrialRun.MARKER_RADIUS = 6
TrialRun.DELIVERY_RADIUS = 10
TrialRun.WARDEN_REACH = 15

local function isFinite(n: number): boolean
	return n > -math.huge and n < math.huge
end

function TrialRun.newRecord(): TrialRecord
	return { cooldowns = {}, questStep = 0 }
end

-- Turns whatever was saved into a valid record. Never errors. Cooldowns keep only known
-- trials with a time still ahead, and never more than a pass cooldown ahead.
function TrialRun.sanitize(raw: any, realNow: number): TrialRecord
	local record = TrialRun.newRecord()
	if type(raw) ~= "table" then
		return record
	end
	local cooldowns = raw.cooldowns
	if type(cooldowns) == "table" and isFinite(realNow) then
		for _, trial in Trials.list do
			local readyAt = cooldowns[trial.id]
			if type(readyAt) == "number" and isFinite(readyAt) and readyAt > realNow then
				record.cooldowns[trial.id] = math.min(readyAt, realNow + TrialRun.PASS_COOLDOWN)
			end
		end
	end
	local step = raw.questStep
	if
		type(step) == "number"
		and step >= 0
		and step < #Trials.quest.steps
		and step == math.floor(step)
	then
		record.questStep = step
	end
	return record
end

-- How much there is to do: markers, creatures, or 1 for a delivery or a duel. 0 if unknown.
function TrialRun.goal(trialId: string): number
	local trial = Trials.byId[trialId]
	if trial == nil then
		return 0
	end
	if trial.kind == "course" then
		local markers = World.courses[trialId]
		return if markers ~= nil then #markers else 0
	elseif trial.kind == "hunt" then
		return trial.count or 1
	end
	return 1
end

-- Seconds until the trial may be taken again: 0 to 300. A time that is not a number reads
-- as the full 300, so a broken clock never opens a trial early.
function TrialRun.cooldownLeft(record: TrialRecord, trialId: string, realNow: number): number
	local readyAt = record.cooldowns[trialId]
	if readyAt == nil then
		return 0
	end
	local left = readyAt - realNow
	if left ~= left then
		return TrialRun.PASS_COOLDOWN
	end
	return math.clamp(left, 0, TrialRun.PASS_COOLDOWN)
end

-- Checks in order: BAD_REQUEST (not a trial id), TRIAL_BUSY, TRIAL_COOLDOWN.
function TrialRun.start(
	record: TrialRecord,
	current: Run?,
	rawId: any,
	clock: number,
	realNow: number
): (Run?, string)
	local trial = if type(rawId) == "string" then Trials.byId[rawId] else nil
	if trial == nil then
		return nil, "BAD_REQUEST"
	end
	if current ~= nil then
		return nil, "TRIAL_BUSY"
	end
	if TrialRun.cooldownLeft(record, trial.id, realNow) > 0 then
		return nil, "TRIAL_COOLDOWN"
	end
	return {
		trialId = trial.id,
		endsAt = clock + trial.seconds,
		progress = 0,
		goal = TrialRun.goal(trial.id),
	},
		"TRIAL_STARTED"
end

local function withProgress(run: Run, progress: number): Run
	local out = table.clone(run)
	out.progress = math.min(progress, run.goal)
	return out
end

-- A course counts marker `index` only when it is the next one.
function TrialRun.reachMarker(run: Run, index: number): Run
	local trial = Trials.byId[run.trialId]
	if trial == nil or trial.kind ~= "course" or index ~= run.progress + 1 then
		return run
	end
	return withProgress(run, run.progress + 1)
end

-- A hunt counts a defeat of its own quarry only.
function TrialRun.countDefeat(run: Run, creature: string): Run
	local trial = Trials.byId[run.trialId]
	if trial == nil or trial.kind ~= "hunt" or trial.creature ~= creature then
		return run
	end
	return withProgress(run, run.progress + 1)
end

-- A delivery made or a duel won.
function TrialRun.complete(run: Run): Run
	local trial = Trials.byId[run.trialId]
	if trial == nil or (trial.kind ~= "delivery" and trial.kind ~= "duel") then
		return run
	end
	return withProgress(run, run.goal)
end

function TrialRun.isPassed(run: Run): boolean
	return run.goal > 0 and run.progress >= run.goal
end

-- Written as a negation so a NaN clock counts as out of time.
function TrialRun.isExpired(run: Run, clock: number): boolean
	return not (clock < run.endsAt)
end

-- The record after a trial ends: its cooldown starts.
function TrialRun.finish(
	record: TrialRecord,
	trialId: string,
	passed: boolean,
	realNow: number
): TrialRecord
	local cooldowns = table.clone(record.cooldowns)
	cooldowns[trialId] = realNow
		+ (if passed then TrialRun.PASS_COOLDOWN else TrialRun.FAIL_COOLDOWN)
	return { cooldowns = cooldowns, questStep = record.questStep }
end

-- `event` is a passed trial's id, or "colossus". It counts only when it is the quest's next
-- step. Returns the new step and whether the quest was completed; a completed quest starts
-- again at step 0. A step that is not a whole number 0..3 reads as 0.
function TrialRun.advanceQuest(step: number, event: string): (number, boolean)
	local steps = Trials.quest.steps
	if not (step >= 0 and step < #steps and step == math.floor(step)) then
		return 0, false
	end
	if steps[step + 1] ~= event then
		return step, false
	end
	if step + 1 >= #steps then
		return 0, true
	end
	return step + 1, false
end

return TrialRun
