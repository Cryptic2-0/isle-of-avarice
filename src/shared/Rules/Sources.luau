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
-- Network and frame jitter allowed on a held prompt.
Sources.HOLD_SLACK = 0.3

-- Whether a held cache's prompt was held long enough. hold is nil for an ordinary cache; began and
-- ended are the server's own times for the prompt starting and ending.
function Sources.holdOk(hold: number?, began: number?, ended: number?, now: number): boolean
	if hold == nil then
		return true
	end
	if began == nil then
		return false
	end
	return (ended or now) - began >= hold - Sources.HOLD_SLACK
end

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

-- Puts a Relic in a free slot: the one way a cache, a creature, a trial or the quest gives
-- one. Checks run in order: data, locked ledger, unknown Relic, sealed, free slots.
function Sources.give(
	ledger: Ledger?,
	relicId: Types.CardId,
	sealed: boolean,
	locked: boolean
): (Ledger?, string)
	if ledger == nil then
		return nil, "DATA_NOT_LOADED"
	end
	if locked then
		return nil, "LEDGER_LOCKED"
	end
	if Relics.byId[relicId] == nil then
		return nil, "UNKNOWN_CARD"
	end
	if sealed then
		return nil, "SEALED"
	end
	local result, err = Ledger.add(ledger, relicId)
	if result == nil then
		return nil, err or "FREE_FULL"
	end
	return result, "GOT_CARD"
end

-- Checks run in order: data, locked ledger, distance, hold, cache, sealed, free slots. A failure returns the
-- same state untouched, so a refused attempt never consumes the cache.
-- On success the fourth value is the time the cache becomes available again.
function Sources.tryCollect(
	state: SourceState,
	ledger: Ledger?,
	cache: Cache,
	now: number,
	distance: number,
	sealed: boolean,
	locked: boolean,
	holdOk: boolean?
): (SourceState, Ledger?, string, number?)
	if ledger == nil then
		return state, nil, "DATA_NOT_LOADED", nil
	end
	if locked then
		return state, nil, "LEDGER_LOCKED", nil
	end
	if not (distance <= Sources.MAX_DISTANCE) then
		return state, nil, "TOO_FAR", nil
	end
	if holdOk == false then
		return state, nil, "HOLD_TOO_SHORT", nil
	end
	if not Sources.isAvailable(state, cache.id, now) then
		return state, nil, "CACHE_EMPTY", nil
	end
	local relic = Relics.byId[cache.relicId]
	if relic == nil then
		return state, nil, "CACHE_EMPTY", nil
	end
	local result, code = Sources.give(ledger, cache.relicId, sealed, locked)
	if result == nil then
		return state, nil, code, nil
	end
	local newState = table.clone(state)
	local availableAt = now + Tiers.info[relic.tier].cacheRespawnSeconds
	newState[cache.id] = availableAt
	return newState, result, "GOT_CARD", availableAt
end

return Sources
