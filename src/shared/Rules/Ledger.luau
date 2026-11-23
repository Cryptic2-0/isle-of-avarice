--!strict
local Cards = require("../Catalog/Cards")
local Relics = require("../Catalog/Relics")
local Types = require("../Types")

type CardId = Types.CardId
type Ledger = Types.Ledger

local Ledger = {}

Ledger.FREE_SLOTS = 20

local function copy(ledger: Ledger): Ledger
	return { claimed = table.clone(ledger.claimed), free = table.clone(ledger.free) }
end

local function validIndex(ledger: Ledger, index: number): boolean
	return index == math.floor(index) and index >= 1 and index <= #ledger.free
end

function Ledger.new(): Ledger
	return { claimed = {}, free = {} }
end

-- Puts a card (a Relic or an Edict) in a free slot.
function Ledger.add(ledger: Ledger, cardId: CardId): (Ledger?, string?)
	if Cards.info(cardId) == nil then
		return nil, "UNKNOWN_CARD"
	end
	if #ledger.free >= Ledger.FREE_SLOTS then
		return nil, "FREE_FULL"
	end
	local result = copy(ledger)
	table.insert(result.free, cardId)
	return result
end

function Ledger.claim(ledger: Ledger, freeIndex: number): (Ledger?, string?)
	if not validIndex(ledger, freeIndex) then
		return nil, "BAD_INDEX"
	end
	local cardId = ledger.free[freeIndex]
	-- Only a Relic has a numbered slot.
	if not Cards.isRelic(cardId) then
		return nil, "NOT_A_RELIC"
	end
	if ledger.claimed[cardId] then
		return nil, "ALREADY_CLAIMED"
	end
	local result = copy(ledger)
	table.remove(result.free, freeIndex)
	result.claimed[cardId] = true
	return result
end

function Ledger.unclaim(ledger: Ledger, cardId: CardId): (Ledger?, string?)
	if not ledger.claimed[cardId] then
		return nil, "NOT_CLAIMED"
	end
	if #ledger.free >= Ledger.FREE_SLOTS then
		return nil, "FREE_FULL"
	end
	local result = copy(ledger)
	result.claimed[cardId] = nil
	table.insert(result.free, cardId)
	return result
end

function Ledger.discard(ledger: Ledger, freeIndex: number): (Ledger?, string?)
	if not validIndex(ledger, freeIndex) then
		return nil, "BAD_INDEX"
	end
	local result = copy(ledger)
	table.remove(result.free, freeIndex)
	return result
end

function Ledger.count(ledger: Ledger, cardId: CardId): number
	local total = if ledger.claimed[cardId] then 1 else 0
	for _, id in ledger.free do
		if id == cardId then
			total += 1
		end
	end
	return total
end

-- Free slots still empty.
function Ledger.room(ledger: Ledger): number
	return math.max(0, Ledger.FREE_SLOTS - #ledger.free)
end

-- True when the free slots hold every card of the list, counting repeats.
function Ledger.holdsFree(ledger: Ledger, cardIds: { CardId }): boolean
	local need: { [CardId]: number } = {}
	for _, id in cardIds do
		need[id] = (need[id] or 0) + 1
	end
	for _, id in ledger.free do
		local left = need[id]
		if left ~= nil then
			need[id] = if left > 1 then left - 1 else nil
		end
	end
	return next(need) == nil
end

-- Takes the listed cards out of the free slots (the first copy of each first), keeping the
-- order of the rest. Nil when the free slots do not hold them all.
function Ledger.remove(ledger: Ledger, cardIds: { CardId }): Ledger?
	if not Ledger.holdsFree(ledger, cardIds) then
		return nil
	end
	local need: { [CardId]: number } = {}
	for _, id in cardIds do
		need[id] = (need[id] or 0) + 1
	end
	local free: { CardId } = {}
	for _, id in ledger.free do
		local left = need[id]
		if left ~= nil and left > 0 then
			need[id] = left - 1
		else
			table.insert(free, id)
		end
	end
	return { claimed = table.clone(ledger.claimed), free = free }
end

-- Edicts held (always in free slots).
function Ledger.edictCount(ledger: Ledger): number
	local total = 0
	for _, id in ledger.free do
		if Cards.isEdict(id) then
			total += 1
		end
	end
	return total
end

-- Relics held, claimed and spare.
function Ledger.relicCount(ledger: Ledger): number
	local total = Ledger.claimedCount(ledger)
	for _, id in ledger.free do
		if Cards.isRelic(id) then
			total += 1
		end
	end
	return total
end

function Ledger.claimedCount(ledger: Ledger): number
	local total = 0
	for _, value in ledger.claimed do
		if value then
			total += 1
		end
	end
	return total
end

function Ledger.isComplete(ledger: Ledger): boolean
	for _, relic in Relics.list do
		if not ledger.claimed[relic.id] then
			return false
		end
	end
	return true
end

-- Turns arbitrary saved data into a valid Ledger. Never errors.
function Ledger.sanitize(raw: any): Ledger
	local result = Ledger.new()
	if type(raw) ~= "table" then
		return result
	end
	local rawClaimed = raw.claimed
	if type(rawClaimed) == "table" then
		for key, value in rawClaimed do
			if type(key) == "string" and Relics.byId[key] ~= nil and value == true then
				result.claimed[key] = true
			end
		end
	end
	local rawFree = raw.free
	if type(rawFree) == "table" then
		-- Saved data can have gaps, so go by the keys that are row numbers, not by the length.
		local rows: { number } = {}
		for key in rawFree do
			if
				type(key) == "number"
				and key >= 1
				and key < math.huge
				and key == math.floor(key)
			then
				table.insert(rows, key)
			end
		end
		table.sort(rows)
		for _, row in rows do
			if #result.free >= Ledger.FREE_SLOTS then
				break
			end
			local id = rawFree[row]
			if Cards.info(id) ~= nil then
				table.insert(result.free, id)
			end
		end
	end
	return result
end

return Ledger
