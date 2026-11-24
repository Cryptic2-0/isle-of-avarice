--!strict
local Abilities = require("../Catalog/Abilities")
local Loadout = require("./Loadout")
local PathProgress = require("./PathProgress")
local Paths = require("../Catalog/Paths")
local Types = require("../Types")

type PathProgress = Types.PathProgress

export type AbilityView = {
	id: string,
	name: string,
	description: string,
	unlockLevel: number,
	unlocked: boolean,
	equippedSlot: number,
}
export type RowView = {
	path: string,
	name: string,
	style: string,
	level: number,
	xpText: string,
	rateText: string,
	isCalling: boolean,
	abilities: { AbilityView },
	changeText: string,
	canChange: boolean,
}
export type SlotView = { slot: number, abilityId: string, name: string }
export type View = {
	needsCalling: boolean,
	callingText: string,
	rows: { RowView },
	slots: { SlotView },
}

local SECONDS_PER_DAY = 86400

local PathView = {}

local function xpText(xp: number, level: number): string
	if level >= PathProgress.MAX_LEVEL then
		return "MAX"
	end
	local floor = PathProgress.totalXpForLevel(level)
	local into = math.floor(xp - floor)
	local needed = PathProgress.totalXpForLevel(level + 1) - floor
	return `{into} / {needed}`
end

local function changeState(progress: PathProgress, coin: number, now: number): (string, boolean)
	-- Mirrors PathProgress.changeCalling: the cooldown applies once a change has been made.
	if
		progress.callingChangedAt > 0
		and not (now - progress.callingChangedAt >= PathProgress.CHANGE_COOLDOWN)
	then
		local left = progress.callingChangedAt + PathProgress.CHANGE_COOLDOWN - now
		return `Available in {math.ceil(left / SECONDS_PER_DAY)} days`, false
	end
	if progress.callingChanges == 0 then
		return "Free", true
	end
	return `{PathProgress.CHANGE_COST} Coin`, coin >= PathProgress.CHANGE_COST
end

function PathView.build(progress: PathProgress, coin: number, now: number): View
	local hasCalling = progress.calling ~= ""
	local slotOf: { [string]: number } = {}
	for slot, id in progress.loadout do
		if id ~= "" then
			slotOf[id] = slot
		end
	end

	local rows: { RowView } = {}
	for _, path in Paths.order do
		local info = Paths.info[path]
		local level = PathProgress.level(progress, path)
		local abilities: { AbilityView } = {}
		for _, ability in Abilities.forPath(path) do
			table.insert(abilities, {
				id = ability.id,
				name = ability.name,
				description = ability.description,
				unlockLevel = ability.unlockLevel,
				unlocked = level >= ability.unlockLevel,
				equippedSlot = slotOf[ability.id] or 0,
			})
		end
		local isCalling = hasCalling and progress.calling == path
		local changeText, canChange = "", false
		if hasCalling and not isCalling then
			changeText, canChange = changeState(progress, coin, now)
		end
		table.insert(rows, {
			path = path,
			name = info.name,
			style = info.style,
			level = level,
			xpText = xpText(progress.xp[path] or 0, level),
			rateText = if hasCalling
				then `{math.floor(PathProgress.learningRate(progress.calling, path) * 100 + 0.5)}%`
				else "—",
			isCalling = isCalling,
			abilities = abilities,
			changeText = changeText,
			canChange = canChange,
		})
	end

	local slots: { SlotView } = {}
	for slot = 1, Loadout.SLOTS do
		local id = progress.loadout[slot] or ""
		local ability = Abilities.byId[id]
		table.insert(
			slots,
			{ slot = slot, abilityId = id, name = if ability then ability.name else "" }
		)
	end

	return {
		needsCalling = not hasCalling,
		callingText = if hasCalling
			then `Calling: {Paths.info[progress.calling :: Types.PathId].name}`
			else "Choose your Calling",
		rows = rows,
		slots = slots,
	}
end

return PathView
