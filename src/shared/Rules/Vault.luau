--!strict
local Ledger = require("./Ledger")
local Relics = require("../Catalog/Relics")
local Types = require("../Types")

type CardId = Types.CardId
type Ledger = Types.Ledger
type Vault = Types.Vault

local MAX_CARD_ID_LENGTH = 16

local Vault = {}

Vault.MAX = 3

function Vault.size(vault: Vault): number
	local total = 0
	for _, value in vault do
		if value then
			total += 1
		end
	end
	return total
end

-- Drops vaulted ids the ledger no longer holds.
function Vault.prune(vault: Vault, ledger: Ledger): Vault
	local result: Vault = {}
	for cardId, value in vault do
		if value and Ledger.count(ledger, cardId) > 0 then
			result[cardId] = true
		end
	end
	return result
end

-- Turns arbitrary saved data into a valid Vault. Never errors.
-- Keeps known, held, non-Crown ids whose value is true; at most MAX, lowest slot numbers first.
function Vault.sanitize(raw: any, ledger: Ledger): Vault
	local result: Vault = {}
	if type(raw) ~= "table" then
		return result
	end
	for _, relic in Relics.list do
		if Vault.size(result) >= Vault.MAX then
			break
		end
		if
			relic.tier ~= "Crown"
			and raw[relic.id] == true
			and Ledger.count(ledger, relic.id) > 0
		then
			result[relic.id] = true
		end
	end
	return result
end

-- Validates a raw client request and applies it to the vault.
-- Request shape: { kind = "add" | "remove", cardId = string }
-- Success: new vault, "VAULTED" | "UNVAULTED", card id.
-- Failure: nil, error code, nil. Never errors on hostile input.
function Vault.apply(
	vault: Vault?,
	ledger: Ledger?,
	raw: any,
	inSafeZone: boolean,
	locked: boolean
): (Vault?, string, CardId?)
	if vault == nil or ledger == nil then
		return nil, "DATA_NOT_LOADED", nil
	end
	if locked then
		return nil, "LEDGER_LOCKED", nil
	end
	if type(raw) ~= "table" then
		return nil, "BAD_REQUEST", nil
	end
	local kind = raw.kind
	local cardId = raw.cardId
	if kind ~= "add" and kind ~= "remove" then
		return nil, "BAD_REQUEST", nil
	end
	if type(cardId) ~= "string" or #cardId > MAX_CARD_ID_LENGTH then
		return nil, "BAD_REQUEST", nil
	end
	if not inSafeZone then
		return nil, "NOT_IN_SAFE_ZONE", nil
	end
	if kind == "add" then
		local relic = Relics.byId[cardId]
		if relic == nil then
			return nil, "UNKNOWN_CARD", nil
		end
		if relic.tier == "Crown" then
			return nil, "CROWN_NO_VAULT", nil
		end
		if Ledger.count(ledger, cardId) == 0 then
			return nil, "NOT_HELD", nil
		end
		if vault[cardId] then
			return nil, "ALREADY_VAULTED", nil
		end
		if Vault.size(vault) >= Vault.MAX then
			return nil, "VAULT_FULL", nil
		end
		local result = table.clone(vault)
		result[cardId] = true
		return result, "VAULTED", cardId
	end
	if not vault[cardId] then
		return nil, "NOT_VAULTED", nil
	end
	local result = table.clone(vault)
	result[cardId] = nil
	return result, "UNVAULTED", cardId
end

return Vault
