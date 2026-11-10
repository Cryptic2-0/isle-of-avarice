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
function Sources.tryCollect(
	state: SourceState,
	ledger: Ledger?,
	cache: Cache,
	now: number,
	distance: number
): (SourceState, Ledger?, string)
	if ledger == nil then
		return state, nil, "DATA_NOT_LOADED"
	end
	if not (distance <= Sources.MAX_DISTANCE) then
		return state, nil, "TOO_FAR"
	end
	if not Sources.isAvailable(state, cache.id, now) then
		return state, nil, "CACHE_EMPTY"
	end
	local relic = Relics.byId[cache.relicId]
	if relic == nil then
		return state, nil, "CACHE_EMPTY"
	end
	local result, err = Ledger.add(ledger, cache.relicId)
	if result == nil then
		return state, nil, err or "FREE_FULL"
	end
	local newState = table.clone(state)
	newState[cache.id] = now + Tiers.info[relic.tier].cacheRespawnSeconds
	return newState, result, "GOT_CARD"
end

return Sources
