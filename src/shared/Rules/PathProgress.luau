--!strict
local Abilities = require("../Catalog/Abilities")
local Paths = require("../Catalog/Paths")
local Types = require("../Types")

type PathProgress = Types.PathProgress
type PathId = Types.PathId

local PathProgress = {}

PathProgress.MAX_LEVEL = 20
PathProgress.CALLING_START_LEVEL = 3
PathProgress.CHANGE_COST = 500
PathProgress.CHANGE_COOLDOWN = 604800

local RATES = { 1, 0.8, 0.6, 0.4 }
local LOADOUT_SIZE = 4

local function indexOf(path: string): number?
	for i, id in Paths.order do
		if id == path then
			return i
		end
	end
	return nil
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function PathProgress.distance(a: PathId, b: PathId): number
	local ia, ib = indexOf(a), indexOf(b)
	if ia == nil or ib == nil then
		return 3
	end
	local d = math.abs(ia - ib)
	return math.min(d, #Paths.order - d)
end

function PathProgress.learningRate(calling: string, path: string): number
	if not Paths.isPath(calling) or not Paths.isPath(path) then
		return 0
	end
	return RATES[PathProgress.distance(calling :: PathId, path :: PathId) + 1] or 0
end

function PathProgress.totalXpForLevel(level: number): number
	return 100 * (level - 1) * level / 2
end

function PathProgress.maxXp(): number
	return PathProgress.totalXpForLevel(PathProgress.MAX_LEVEL)
end

function PathProgress.levelForXp(xp: number): number
	if type(xp) ~= "number" or not (xp > 0) then
		return 1
	end
	for level = PathProgress.MAX_LEVEL, 2, -1 do
		if xp >= PathProgress.totalXpForLevel(level) then
			return level
		end
	end
	return 1
end

function PathProgress.level(progress: PathProgress, path: string): number
	local xp = progress.xp[path]
	if xp == nil then
		return 1
	end
	return PathProgress.levelForXp(xp)
end

function PathProgress.new(): PathProgress
	local xp: { [string]: number } = {}
	for _, path in Paths.order do
		xp[path] = 0
	end
	return {
		calling = "",
		xp = xp,
		loadout = table.create(LOADOUT_SIZE, ""),
		callingChanges = 0,
		callingChangedAt = 0,
	}
end

local function copy(progress: PathProgress): PathProgress
	return {
		calling = progress.calling,
		xp = table.clone(progress.xp),
		loadout = table.clone(progress.loadout),
		callingChanges = progress.callingChanges,
		callingChangedAt = progress.callingChangedAt,
	}
end

function PathProgress.unlocked(progress: PathProgress): { string }
	local result = {}
	for _, ability in Abilities.list do
		if PathProgress.level(progress, ability.path) >= ability.unlockLevel then
			table.insert(result, ability.id)
		end
	end
	return result
end

local function unlockedBetween(path: string, before: number, after: number): { string }
	local result = {}
	for _, ability in Abilities.forPath(path :: PathId) do
		if ability.unlockLevel > before and ability.unlockLevel <= after then
			table.insert(result, ability.id)
		end
	end
	return result
end

function PathProgress.chooseCalling(
	progress: PathProgress,
	raw: any
): (PathProgress?, string, { string })
	if not Paths.isPath(raw) then
		return nil, "BAD_REQUEST", {}
	end
	if progress.calling ~= "" then
		return nil, "CALLING_ALREADY_SET", {}
	end
	local path = raw :: string
	local result = copy(progress)
	local before = PathProgress.level(progress, path)
	result.calling = path
	local start = PathProgress.totalXpForLevel(PathProgress.CALLING_START_LEVEL)
	result.xp[path] = math.max(result.xp[path] or 0, start)
	local after = PathProgress.level(result, path)
	return result, "CALLING_CHOSEN", unlockedBetween(path, before, after)
end

function PathProgress.changeCalling(
	progress: PathProgress,
	raw: any,
	coin: number,
	now: number
): (PathProgress?, string, number)
	if not Paths.isPath(raw) then
		return nil, "BAD_REQUEST", 0
	end
	if progress.calling == "" then
		return nil, "NO_CALLING", 0
	end
	if progress.calling == raw then
		return nil, "CALLING_SAME", 0
	end
	-- Written so NaN fails safe: only a clearly elapsed cooldown passes.
	if
		progress.callingChangedAt > 0
		and not (now - progress.callingChangedAt >= PathProgress.CHANGE_COOLDOWN)
	then
		return nil, "CALLING_COOLDOWN", 0
	end
	local cost = if progress.callingChanges == 0 then 0 else PathProgress.CHANGE_COST
	if not (coin >= cost) then
		return nil, "NOT_ENOUGH_COIN", 0
	end
	local result = copy(progress)
	result.calling = raw :: string
	result.callingChanges = progress.callingChanges + 1
	result.callingChangedAt = now
	return result, "CALLING_CHANGED", cost
end

function PathProgress.addXp(
	progress: PathProgress,
	path: string,
	base: number
): (PathProgress, number, number, { string })
	if not Paths.isPath(path) or progress.calling == "" or not finite(base) or not (base > 0) then
		return progress, 0, 0, {}
	end
	local rate = PathProgress.learningRate(progress.calling, path)
	local current = progress.xp[path] or 0
	local room = math.max(0, PathProgress.maxXp() - current)
	local gained = math.min(math.max(0, math.floor(base * rate)), room)
	if not (gained > 0) then
		return progress, 0, 0, {}
	end
	local result = copy(progress)
	result.xp[path] = current + gained
	local before = PathProgress.levelForXp(current)
	local after = PathProgress.levelForXp(current + gained)
	return result, gained, after - before, unlockedBetween(path, before, after)
end

-- Turns arbitrary saved data into valid PathProgress. Never errors.
function PathProgress.sanitize(raw: any): PathProgress
	local result = PathProgress.new()
	if type(raw) ~= "table" then
		return result
	end
	if Paths.isPath(raw.calling) then
		result.calling = raw.calling
	end
	local rawXp = raw.xp
	if type(rawXp) == "table" then
		for _, path in Paths.order do
			local value = rawXp[path]
			if finite(value) then
				result.xp[path] = math.clamp(value, 0, PathProgress.maxXp())
			end
		end
	end
	if finite(raw.callingChanges) and raw.callingChanges >= 0 then
		result.callingChanges = raw.callingChanges
	end
	if finite(raw.callingChangedAt) and raw.callingChangedAt >= 0 then
		result.callingChangedAt = raw.callingChangedAt
	end
	local rawLoadout = raw.loadout
	if type(rawLoadout) == "table" then
		local owned = {}
		for _, id in PathProgress.unlocked(result) do
			owned[id] = true
		end
		local used = {}
		for i = 1, LOADOUT_SIZE do
			local id = rawLoadout[i]
			if type(id) == "string" and owned[id] and not used[id] then
				used[id] = true
				result.loadout[i] = id
			end
		end
	end
	return result
end

return PathProgress
