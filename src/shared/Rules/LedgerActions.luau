--!strict
local Ledger = require("./Ledger")
local Types = require("../Types")

type CardId = Types.CardId
type Ledger = Types.Ledger

local MAX_CARD_ID_LENGTH = 16

local LedgerActions = {}

-- Validates a raw client request and applies it to the ledger.
-- Request shapes:
--   { kind = "claim" | "discard", freeIndex = number, cardId = string }
--   { kind = "unclaim", cardId = string }
-- claim and discard carry the card the player saw on that row; if the free list has
-- shifted (a double click), the card at freeIndex differs and the request is BAD_INDEX.
-- Success: new ledger, "CLAIMED" | "UNCLAIMED" | "DISCARDED", affected card id.
-- Failure: nil, error code, nil. Never errors on hostile input.
function LedgerActions.apply(ledger: Ledger?, raw: any): (Ledger?, string, CardId?)
	if ledger == nil then
		return nil, "DATA_NOT_LOADED", nil
	end
	if type(raw) ~= "table" then
		return nil, "BAD_REQUEST", nil
	end
	local kind = raw.kind
	if kind == "claim" or kind == "discard" then
		local freeIndex = raw.freeIndex
		if type(freeIndex) ~= "number" then
			return nil, "BAD_REQUEST", nil
		end
		local shownCardId = raw.cardId
		if type(shownCardId) ~= "string" or #shownCardId > MAX_CARD_ID_LENGTH then
			return nil, "BAD_REQUEST", nil
		end
		local cardId = ledger.free[freeIndex]
		if cardId ~= shownCardId then
			return nil, "BAD_INDEX", nil
		end
		local result, err
		if kind == "claim" then
			result, err = Ledger.claim(ledger, freeIndex)
		else
			result, err = Ledger.discard(ledger, freeIndex)
		end
		if result == nil then
			return nil, err or "BAD_REQUEST", nil
		end
		return result, if kind == "claim" then "CLAIMED" else "DISCARDED", cardId
	elseif kind == "unclaim" then
		local cardId = raw.cardId
		if type(cardId) ~= "string" or #cardId > MAX_CARD_ID_LENGTH then
			return nil, "BAD_REQUEST", nil
		end
		local result, err = Ledger.unclaim(ledger, cardId)
		if result == nil then
			return nil, err or "BAD_REQUEST", nil
		end
		return result, "UNCLAIMED", cardId
	end
	return nil, "BAD_REQUEST", nil
end

return LedgerActions
