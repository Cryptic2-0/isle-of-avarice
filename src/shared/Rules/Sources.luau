--!strict
local Ledger = require("./Ledger")
local Relics = require("../Catalog/Relics")
local Tiers = require("../Catalog/Tiers")
local Types = require("../Types")

type Cache = Types.Cache
type Ledger = Types.Ledger

-- cache id -> time it becomes available
export type SourceState = { [string]: number }

local Sources = {}

Sources.MAX_DISTANCE = 15

function Sources.new(caches: { Cache }): SourceState
	local state: SourceState = {}
	for _, cache in caches do
		state[cache.id] = 0
	end
	return state
end

function Sources.isAvailable(state: SourceState, cacheId: string, now: number): boolean
	local availableAt = state[cacheId]
	return availableAt ~= nil and now >= availableAt
end

-- Checks run in order: data, distance, cache, free slots. A failure returns the
-- same state untouched, so a refused attempt never consumes the cache.
-- On success the fourth value is the time the cache becomes available again.
function Sources.tryCollect(
	state: SourceState,
	ledger: Ledger?,
	cache: Cache,
	now: number,
	distance: number
): (SourceState, Ledger?, string, number?)
	if ledger == nil then
		return state, nil, "DATA_NOT_LOADED", nil
	end
	if not (distance <= Sources.MAX_DISTANCE) then
		return state, nil, "TOO_FAR", nil
	end
	if not Sources.isAvailable(state, cache.id, now) then
		return state, nil, "CACHE_EMPTY", nil
	end
	local relic = Relics.byId[cache.relicId]
	if relic == nil then
		return state, nil, "CACHE_EMPTY", nil
	end
	local result, err = Ledger.add(ledger, cache.relicId)
	if result == nil then
		return state, nil, err or "FREE_FULL", nil
	end
	local newState = table.clone(state)
	local availableAt = now + Tiers.info[relic.tier].cacheRespawnSeconds
	newState[cache.id] = availableAt
	return newState, result, "GOT_CARD", availableAt
end

return Sources
