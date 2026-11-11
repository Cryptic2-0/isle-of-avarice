--!strict
local Ledger = require("./Ledger")
local Relics = require("../Catalog/Relics")
local Types = require("../Types")

type CardId = Types.CardId
type Ledger = Types.Ledger
type Vault = Types.Vault

export type Claim = {
	picksLeft: number,
	expiresAt: number,
	taken: { [string]: number },
	picked: { [string]: string },
	takenIds: { CardId },
}

local BlindClaim = {}

BlindClaim.PICKS = 5
BlindClaim.DURATION = 30
BlindClaim.TIER_LIMIT = { Crown = 1, Platinum = 1, Gold = 2, Silver = 3, Copper = 3 }

function BlindClaim.start(now: number): Claim
	return {
		picksLeft = BlindClaim.PICKS,
		expiresAt = now + BlindClaim.DURATION,
		taken = {},
		picked = {},
		takenIds = {},
	}
end

function BlindClaim.isOpen(claim: Claim, now: number): boolean
	return claim.picksLeft > 0 and now < claim.expiresAt
end

-- Spends one pick on a slot. Refusals return the inputs untouched and spend nothing.
-- rawSlot comes straight from a client: any type, never raises.
function BlindClaim.pick(
	claim: Claim,
	victim: Ledger,
	victimVault: Vault,
	killer: Ledger,
	rawSlot: any,
	now: number
): (Claim, Ledger, Ledger, string, CardId?)
	if not BlindClaim.isOpen(claim, now) then
		return claim, victim, killer, "CLAIM_OVER"
	end
	if
		type(rawSlot) ~= "number"
		or rawSlot ~= rawSlot
		or rawSlot < 1
		or rawSlot > Relics.count
		or rawSlot ~= math.floor(rawSlot)
	then
		return claim, victim, killer, "BAD_SLOT"
	end
	local slot: number = rawSlot
	local key = tostring(slot)
	if claim.picked[key] ~= nil then
		return claim, victim, killer, "ALREADY_PICKED"
	end
	local relic = Relics.list[slot]
	local limit = BlindClaim.TIER_LIMIT[relic.tier] or 0
	if (claim.taken[relic.tier] or 0) >= limit then
		return claim, victim, killer, "TIER_LIMIT"
	end

	local result: Claim = {
		picksLeft = claim.picksLeft - 1,
		expiresAt = claim.expiresAt,
		taken = table.clone(claim.taken),
		picked = table.clone(claim.picked),
		takenIds = table.clone(claim.takenIds),
	}

	local newKiller = nil
	if Ledger.count(victim, relic.id) > 0 and victimVault[relic.id] ~= true then
		newKiller = Ledger.add(killer, relic.id)
	end
	if newKiller == nil then
		result.picked[key] = "MISS"
		return result, victim, killer, "MISS"
	end

	local newVictim: Ledger =
		{ claimed = table.clone(victim.claimed), free = table.clone(victim.free) }
	local index = table.find(newVictim.free, relic.id)
	if index ~= nil then
		table.remove(newVictim.free, index)
	else
		newVictim.claimed[relic.id] = nil
	end
	result.picked[key] = "TAKEN"
	result.taken[relic.tier] = (result.taken[relic.tier] or 0) + 1
	table.insert(result.takenIds, relic.id)
	return result, newVictim, newKiller, "TAKEN", relic.id
end

return BlindClaim
