--!strict
-- Text for the Warden's offer window and the trial HUD.
local Relics = require("../Catalog/Relics")
local Scarcity = require("./Scarcity")
local TrialRun = require("./TrialRun")
local Trials = require("../Catalog/Trials")
local Types = require("../Types")

export type OfferView = {
	trialId: string,
	title: string,
	warden: string,
	goal: string,
	timeText: string,
	rewardText: string,
	relicText: string,
	sealed: boolean,
	canStart: boolean,
	note: string,
}
export type HudState = { trialId: string, progress: number, goal: number, secondsLeft: number }

local TrialView = {}

local QUEST_NEXT: { [string]: string } = {
	colossus = "defeat the Brine Colossus",
}

-- "M:SS", seconds rounded up. Below 0 or not a number reads 0:00.
local function clock(seconds: number): string
	local whole = if seconds > 0 and seconds < math.huge then math.ceil(seconds) else 0
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- `running`: the id of the trial the player is in, if any. `held`: copies of the trial's
-- Relic on the server. `freeSlots`: free slots the player can fill (0 with a locked Ledger).
function TrialView.offer(
	trialId: string,
	record: Types.TrialRecord,
	running: string?,
	realNow: number,
	held: number,
	freeSlots: number
): OfferView
	local trial = Trials.byId[trialId]
	if trial == nil then
		return {
			trialId = trialId,
			title = "",
			warden = "",
			goal = "",
			timeText = "",
			rewardText = "",
			relicText = "",
			sealed = false,
			canStart = false,
			note = "",
		}
	end
	local relic = Relics.byId[trial.relicId]
	local sealed = Scarcity.isSealed(trial.relicId, held)
	local relicText = if relic ~= nil then `Relic: {relic.name} ({relic.tier})` else "Relic: none"
	if sealed then
		relicText ..= " — sealed on this server"
	end

	local canStart, note = true, ""
	local left = TrialRun.cooldownLeft(record, trialId, realNow)
	if running ~= nil then
		canStart, note = false, "Finish your current trial first."
	elseif left > 0 then
		canStart, note = false, `Try again in {clock(left)}.`
	elseif not sealed and not (freeSlots > 0) then
		note = "Your free slots are full, so the Relic would be lost."
	end

	return {
		trialId = trialId,
		title = trial.name,
		warden = trial.warden,
		goal = trial.goal,
		timeText = `Time: {trial.seconds} seconds`,
		rewardText = `Reward: {trial.coin} Coin, {trial.xp} XP`,
		relicText = relicText,
		sealed = sealed,
		canStart = canStart,
		note = note,
	}
end

-- The HUD lines: the running trial and its clock, if any, then always the quest line.
function TrialView.hud(state: HudState?, questStep: number): { string }
	local lines: { string } = {}
	local trial = if state ~= nil then Trials.byId[state.trialId] else nil
	if state ~= nil and trial ~= nil then
		local progress: string
		if trial.kind == "course" then
			progress = `marker {state.progress} / {state.goal}`
		elseif trial.kind == "hunt" then
			progress = `defeated {state.progress} / {state.goal}`
		elseif trial.kind == "delivery" then
			progress = "carry the parcel to the Harbour Warden"
		else
			progress = "defeat the Drowned Tallyman"
		end
		table.insert(lines, `{trial.name}: {progress}`)
		table.insert(lines, `Time left {clock(state.secondsLeft)}`)
	end

	local steps = Trials.quest.steps
	local step = questStep
	if not (step >= 0 and step < #steps and step == math.floor(step)) then
		step = 0
	end
	local nextId = steps[step + 1]
	local nextTrial = Trials.byId[nextId]
	local nextText = if nextTrial ~= nil then nextTrial.name else QUEST_NEXT[nextId] or nextId
	table.insert(lines, `{Trials.quest.name}: {step} / {#steps}, next: {nextText}`)
	return lines
end

return TrialView
