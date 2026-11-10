--!strict
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

function Ledger.add(ledger: Ledger, cardId: CardId): (Ledger?, string?)
	if Relics.byId[cardId] == nil then
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
		for i = 1, #rawFree do
			if #result.free >= Ledger.FREE_SLOTS then
				break
			end
			local id = rawFree[i]
			if type(id) == "string" and Relics.byId[id] ~= nil then
				table.insert(result.free, id)
			end
		end
	end
	return result
end

return Ledger
