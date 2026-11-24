--!strict
local Abilities = require("../Catalog/Abilities")
local PathProgress = require("./PathProgress")
local Types = require("../Types")

type PathProgress = Types.PathProgress

local MAX_ABILITY_ID_LENGTH = 16

local Loadout = {}

Loadout.SLOTS = 4

local function copy(progress: PathProgress): PathProgress
	return {
		calling = progress.calling,
		xp = table.clone(progress.xp),
		loadout = table.clone(progress.loadout),
		callingChanges = progress.callingChanges,
		callingChangedAt = progress.callingChangedAt,
	}
end

-- request: { slot = number, abilityId = string }; "" clears the slot.
function Loadout.apply(
	progress: PathProgress?,
	raw: any,
	inSafeZone: boolean
): (PathProgress?, string)
	if progress == nil then
		return nil, "DATA_NOT_LOADED"
	end
	if type(raw) ~= "table" then
		return nil, "BAD_REQUEST"
	end
	local slot, abilityId = raw.slot, raw.abilityId
	if
		type(slot) ~= "number"
		or slot ~= slot
		or slot ~= math.floor(slot)
		or slot < 1
		or slot > Loadout.SLOTS
	then
		return nil, "BAD_REQUEST"
	end
	if type(abilityId) ~= "string" or #abilityId > MAX_ABILITY_ID_LENGTH then
		return nil, "BAD_REQUEST"
	end
	if abilityId ~= "" and Abilities.byId[abilityId] == nil then
		return nil, "BAD_REQUEST"
	end
	if progress.calling == "" then
		return nil, "NO_CALLING"
	end
	if not inSafeZone then
		return nil, "LOADOUT_SAFE_ZONE"
	end
	if abilityId ~= "" and not table.find(PathProgress.unlocked(progress), abilityId) then
		return nil, "NOT_UNLOCKED"
	end
	local result = copy(progress)
	if abilityId ~= "" then
		for i, id in result.loadout do
			if id == abilityId then
				result.loadout[i] = ""
			end
		end
	end
	result.loadout[slot] = abilityId
	return result, "LOADOUT_CHANGED"
end

-- Each id not yet equipped goes into the first empty slot, if any.
function Loadout.autoFill(progress: PathProgress, ids: { string }): PathProgress
	local result = copy(progress)
	for _, id in ids do
		if not table.find(result.loadout, id) then
			local empty = table.find(result.loadout, "")
			if empty ~= nil then
				result.loadout[empty] = id
			end
		end
	end
	return result
end

return Loadout
